from __future__ import annotations

import hashlib
from datetime import datetime
from difflib import get_close_matches

from app.core.cache import cache_get_json, cache_set_json
from app.db.models import Trip
from app.services.places import places_client
from app.schemas.poi import (
    POI,
    OpeningHours,
    OpeningPeriod,
    OpeningPeriodPoint,
)


def build_places_query(trip: Trip) -> str:
    prefs = trip.preferences or {}
    themes = prefs.get("themes", [])
    theme_query = " ".join(themes) if themes else ""
    return f"{theme_query} things to do in {trip.destination_city}".strip()


async def get_pois(query: str, max_results: int = 20) -> tuple[list[dict], bool]:
    cache_key = "places:" + hashlib.sha256(query.encode("utf-8")).hexdigest()

    cached = await cache_get_json(cache_key)
    if cached is not None:
        return cached, True

    data = await places_client.search_text(query=query, max_results=max_results)
    pois = data.get("places", [])
    await cache_set_json(cache_key, pois, ttl_seconds=60 * 60 * 6)
    return pois, False


async def get_pois_for_trip(trip: Trip, max_results: int = 10) -> tuple[str, list[dict], bool]:
    query = build_places_query(trip)
    cache_key = "places:" + hashlib.sha256(query.encode("utf-8")).hexdigest()

    cached = await cache_get_json(cache_key)
    if cached is not None:
        return query, cached, True

    data = await places_client.search_text(query=query, max_results=max_results)
    pois = data.get("places", [])
    await cache_set_json(cache_key, pois, ttl_seconds=60 * 60 * 6)
    return query, pois, False


def map_opening_hours(raw: dict | None) -> OpeningHours | None:
    if not raw:
        return None

    periods = []
    for period in raw.get("periods", []) or []:
        open_raw = period.get("open")
        close_raw = period.get("close")

        if not open_raw or "day" not in open_raw or "hour" not in open_raw:
            continue

        open_point = OpeningPeriodPoint(
            day=open_raw["day"],
            hour=open_raw["hour"],
            minute=open_raw.get("minute", 0),
        )

        close_point = None
        if close_raw and "day" in close_raw and "hour" in close_raw:
            close_point = OpeningPeriodPoint(
                day=close_raw["day"],
                hour=close_raw["hour"],
                minute=close_raw.get("minute", 0),
            )

        periods.append(OpeningPeriod(open=open_point, close=close_point))

    weekday_descriptions_raw = raw.get("weekdayDescriptions", []) or []
    weekday_descriptions = []
    for desc in weekday_descriptions_raw:
        if isinstance(desc, str):
            weekday_descriptions.append(desc)
        elif isinstance(desc, dict):
            weekday_descriptions.append(desc.get("text", ""))

    return OpeningHours(
        open_now=raw.get("openNow"),
        weekday_text=weekday_descriptions,
        periods=periods,
    )

def get_opening_hours_for_day(
    opening_hours: OpeningHours | None,
    trip_date: datetime | None,
) -> str | None:
    if not opening_hours or not trip_date:
        return None

    weekday_text = opening_hours.weekday_text or []
    if not weekday_text:
        return None

    # Python weekday(): Monday=0 ... Sunday=6
    py_day = trip_date.weekday()

    if 0 <= py_day < len(weekday_text):
        return weekday_text[py_day]

    return None

def normalize_name(value) -> str:
    # support object-based mustVisit
    if isinstance(value, dict):
        value = value.get("place_name") or value.get("name") or ""

    if not value:
        return ""

    return " ".join(str(value).lower().split())


def find_matching_pois(must_visit: list, normalized_pois: list[POI]) -> dict[str, POI]:
    matches: dict[str, POI] = {}
    poi_names = [p.name for p in normalized_pois if p.name]

    for mv in must_visit:
        mv_norm = normalize_name(mv)
        if not mv_norm:
            continue

        # exact / contains check first
        for poi in normalized_pois:
            if not poi.name:
                continue

            poi_norm = normalize_name(poi.name)

            if mv_norm in poi_norm or poi_norm in mv_norm:
                matches[mv_norm] = poi
                break

        if mv_norm in matches:
            continue

        # fuzzy fallback
        close = get_close_matches(mv_norm, [normalize_name(n) for n in poi_names], n=1, cutoff=0.65)

        if close:
            matched_norm = close[0]
            poi = next(
                (p for p in normalized_pois if normalize_name(p.name) == matched_norm),
                None,
            )
            if poi:
                matches[mv_norm] = poi

    return matches


async def fetch_missing_must_visit_pois(
    trip: Trip,
    must_visit: list[str],
    existing_pois: list[POI],
) -> list[POI]:
    matches = find_matching_pois(must_visit, existing_pois)
    missing = [
        mv for mv in must_visit
        if normalize_name(mv) and normalize_name(mv) not in matches
    ]

    extra_pois: list[POI] = []
    seen_ids = {p.id for p in existing_pois}

    for mv in missing:
        query = f"{normalize_name(mv)} in {trip.destination_city}"
        data = await places_client.search_text(query=query, max_results=5)
        raw_places = data.get("places", [])
        normalized = normalize_pois(raw_places)

        if not normalized:
            continue

        # pick best candidate
        best = normalized[0]
        if best.id not in seen_ids:
            extra_pois.append(best)
            seen_ids.add(best.id)

    return extra_pois


def normalize_pois(pois: list[dict]) -> list[POI]:
    normalized: list[POI] = []

    for p in pois:
        display_name = p.get("displayName", {})
        name = display_name.get("text") if isinstance(display_name, dict) else None

        raw_id = p.get("id") or p.get("name")
        if isinstance(raw_id, str) and raw_id.startswith("places/"):
            place_id = raw_id.split("/", 1)[1]
        else:
            place_id = raw_id

        if not name or not place_id:
            continue

        photo_refs = []
        for photo in p.get("photos", []) or []:
            photo_name = photo.get("name")
            if photo_name:
                photo_refs.append(photo_name)

        normalized.append(
            POI(
                id=place_id,
                name=name,
                address=p.get("formattedAddress"),
                rating=p.get("rating"),
                price_level=p.get("priceLevel"),
                types=p.get("types", []) or [],
                lat=p.get("location", {}).get("latitude"),
                lng=p.get("location", {}).get("longitude"),
                website=None, # to be filled in details step
                opening_hours=map_opening_hours(p.get("regularOpeningHours")),
                reviews=[],   # to be filled in details step 
            )
        )

    return normalized