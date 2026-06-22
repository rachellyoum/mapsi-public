import json
from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.ext.asyncio import AsyncSession
from openai import RateLimitError, AuthenticationError, APIConnectionError, BadRequestError
import hashlib

from app.core.deps import get_current_db_user
from app.db.deps import get_db
from app.db.models import User
from app.services.itinerary import generate_itinerary
from app.core.cache import cache_get_json, cache_set_json
from app.services.pois import (
    get_pois_for_trip,
    normalize_pois,
    get_opening_hours_for_day,
    fetch_missing_must_visit_pois,
    find_matching_pois,
)
from app.services.trips import require_trip_edit_access
from app.services.transport import attach_transport_to_itinerary_dict
from app.services.budget import apply_budget_to_itinerary

router = APIRouter(prefix="/trips", tags=["itinerary"])

def to_compact_poi(p):
    return {
        "place_name": getattr(p, "name", None) or getattr(p, "place_name", None),
        "place_id": getattr(p, "id", None) or getattr(p, "place_id", None),
        "lat": getattr(p, "lat", None),
        "lng": getattr(p, "lng", None),
        "type": (
            getattr(p, "type", None)
            or getattr(p, "primary_type", None)
            or getattr(p, "types", None)
        ),
        "rating": getattr(p, "rating", None),
        "address": getattr(p, "address", None),
        "price_level": getattr(p, "price_level", None),
    }

def apply_daily_opening_hours(itinerary_json: dict, normalized_pois: list, start_datetime):
    poi_map = {p.id: p for p in normalized_pois}

    for day in itinerary_json.get("days", []):
        day_number = day.get("day")
        if not start_datetime or not day_number:
            continue

        trip_date = start_datetime + timedelta(days=day_number - 1)

        for stop in day.get("stops", []):
            place_id = stop.get("place_id")
            poi = poi_map.get(place_id)

            if not poi:
                continue

            stop["opening_hours"] = get_opening_hours_for_day(
                poi.opening_hours,
                trip_date,
            )

    return itinerary_json

def remove_duplicate_place_names(itinerary_json: dict) -> dict:
    seen_names = set()

    for day in itinerary_json.get("days", []):
        cleaned_stops = []

        for stop in day.get("stops", []):
            name = (stop.get("place_name") or "").strip().lower()

            if not name:
                cleaned_stops.append(stop)
                continue

            if name in seen_names:
                continue

            seen_names.add(name)
            cleaned_stops.append(stop)

        day["stops"] = cleaned_stops

        for idx, stop in enumerate(day["stops"]):
            stop["order"] = idx + 1

    return itinerary_json


@router.post("/{trip_id}/itinerary/generate")
async def generate_trip_itinerary(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    trip = await require_trip_edit_access(db, trip_id, user.id)

    _, pois, _ = await get_pois_for_trip(trip, max_results=10)
    normalized_pois = normalize_pois(pois) if pois else []

    if not trip.start_datetime or not trip.end_datetime:
        raise HTTPException(status_code=400, detail="Trip is missing start or end datetime")

    start_datetime = trip.start_datetime
    end_datetime = trip.end_datetime

    prefs = trip.preferences or {}
    must_visit = prefs.get("must_visit", []) or prefs.get("mustVisit", [])

    if must_visit:
        extra_must_visit_pois = await fetch_missing_must_visit_pois(
            trip=trip,
            must_visit=must_visit,
            existing_pois=normalized_pois,
        )
        normalized_pois.extend(extra_must_visit_pois)
        must_visit_matches = find_matching_pois(must_visit, normalized_pois)
        prioritized = list(must_visit_matches.values())
        seen_ids = {p.id for p in prioritized}
        remaining = [p for p in normalized_pois if p.id not in seen_ids]
        normalized_pois = prioritized + remaining

    prefs_str = json.dumps(trip.preferences or {}, sort_keys=True)
    key_str = f"{trip.id}|{trip.destination_city}|{start_datetime}|{end_datetime}|{trip.travelers_count}|{prefs_str}"
    cache_key = "itinerary:" + hashlib.sha256(key_str.encode("utf-8")).hexdigest()

    cached = await cache_get_json(cache_key)
    if cached is not None:
        cached = apply_daily_opening_hours(cached, normalized_pois, start_datetime)
        cached = apply_budget_to_itinerary(cached)

        trip.itinerary_json = cached
        trip.status = "generated"
        await db.commit()
        await db.refresh(trip)

        return {"trip_id": trip.id, "itinerary": cached, "cached": True}

    try:
        compact_pois = [to_compact_poi(p) for p in normalized_pois[:10]] if normalized_pois else None
        itinerary_json = await generate_itinerary(
            destination_city=trip.destination_city,
            start_datetime=start_datetime,
            end_datetime=end_datetime,
            travelers_count=trip.travelers_count or 1,
            preferences=trip.preferences or {},
            pois=compact_pois,
            must_visit=must_visit,
        )
        itinerary_json = remove_duplicate_place_names(itinerary_json)
        itinerary_json = await attach_transport_to_itinerary_dict(itinerary_json)
        itinerary_json = apply_daily_opening_hours(itinerary_json, normalized_pois, start_datetime)
        itinerary_json = apply_budget_to_itinerary(itinerary_json)
    except RateLimitError:
        raise HTTPException(status_code=429, detail="OpenAI quota exceeded.")
    except AuthenticationError:
        raise HTTPException(status_code=401, detail="Invalid OpenAI API key.")
    except APIConnectionError:
        raise HTTPException(status_code=503, detail="Could not reach OpenAI.")
    except BadRequestError as e:
        raise HTTPException(status_code=400, detail=f"OpenAI bad request: {e}")
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected itinerary error: {type(e).__name__}: {str(e)}"
        )

    await cache_set_json(cache_key, itinerary_json, ttl_seconds=60 * 60 * 24)

    trip.itinerary_json = itinerary_json
    trip.status = "generated"
    await db.commit()
    await db.refresh(trip)

    return {"trip_id": trip.id, "itinerary": itinerary_json, "cached": False}

@router.delete("/{trip_id}/itinerary", status_code=204)
async def delete_trip_itinerary(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    trip = await require_trip_edit_access(db, trip_id, user.id)

    trip.itinerary_json = None
    trip.status = "draft"

    await db.commit()

    return Response(status_code=204)