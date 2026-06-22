import hashlib
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.cache import cache_get_json, cache_set_json
from app.core.deps import get_current_db_user
from app.db.deps import get_db
from app.db.models import User
from app.services.places import places_client
from app.services.pois import get_pois_for_trip
from app.services.trips import require_trip_view_access

router = APIRouter(tags=["places"])

@router.get("/mustvisitsearch")
async def search_places_before_trip(
    q: str = Query(..., min_length=1),
    city: str = Query(..., min_length=1),
    country: str | None = Query(None),
    user: User = Depends(get_current_db_user),
):
    destination_parts = [city, country]
    destination_text = ", ".join([p for p in destination_parts if p])

    search_query = f"{q} in {destination_text}" if destination_text else q

    try:
        data = await places_client.search_text(search_query, max_results=10)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to search places: {type(e).name}: {str(e)}",
        )

    places = []

    for p in data.get("places", []):
        if not p.get("displayName"):
            continue

        photo_ref = None
        if p.get("photos"):
            photo_ref = p["photos"][0].get("name")

        places.append({
            "place_id": p.get("id"),
            "id": p.get("id"),
            "place_name": p.get("displayName", {}).get("text"),
            "name": p.get("displayName", {}).get("text"),
            "address": p.get("formattedAddress"),
            "rating": p.get("rating"),
            "price_level": p.get("priceLevel"),
            "types": p.get("types", []),
            "type": p.get("types", [None])[0] if p.get("types") else None,
            "lat": p.get("location", {}).get("latitude"),
            "lng": p.get("location", {}).get("longitude"),
            "photo_url": f"media/photos?photo_ref={photo_ref}" if photo_ref else None,
            "maps_url": places_client.build_maps_link(p.get("id")) if p.get("id") else None,
        })

    return {
        "query": q,
        "query_used": search_query,
        "places": places,
    }

@router.post("/trips/{trip_id}/places/search")
async def search_places_for_trip(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    trip = await require_trip_view_access(db, trip_id, user.id)

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    query, places, cached = await get_pois_for_trip(trip, max_results=10)
    return {
        "trip_id": trip.id,
        "query_used": query,
        "places": [
            {
                "id": p.get("id"),
                "name": p.get("displayName", {}).get("text"),
                "address": p.get("formattedAddress"),
                "rating": p.get("rating"),
                "price_level": p.get("priceLevel"),
                "types": p.get("types", []),
                "lat": p.get("location", {}).get("latitude"),
                "lng": p.get("location", {}).get("longitude"),
                "photo_url": [f"media/photos?photo_ref={p.get('photos', [])[0].get('name')}" if p.get("photos") else None]
            }
            for p in places
            if p.get("displayName")
        ],
        "cached": cached,
    }

@router.get("/places/{place_id}/details")
async def get_place_details(
    place_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    cache_key = "place_details:v1:" + hashlib.sha256(place_id.encode("utf-8")).hexdigest()

    cached = await cache_get_json(cache_key)
    if cached is not None:
        return cached

    try:
        data = await places_client.get_place_details(place_id)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to fetch place details: {type(e).__name__}: {str(e)}",
        )

    website = (
        data.get("websiteUri")
        or data.get("googleMapsUri")
        or places_client.build_maps_link(place_id)
    )

    reviews = []
    for r in data.get("reviews", []) or []:
        author_raw = r.get("authorAttribution") or {}

        text_raw = r.get("text")
        if isinstance(text_raw, dict):
            text_value = text_raw.get("text")
        else:
            text_value = text_raw

        reviews.append(
            {
                "rating": r.get("rating"),
                "text": text_value,
                "publish_time": r.get("publishTime"),
                "relative_publish_time_description": r.get("relativePublishTimeDescription"),
                "author": {
                    "display_name": author_raw.get("displayName"),
                    "uri": author_raw.get("uri"),
                    "photo_uri": author_raw.get("photoUri"),
                },
            }
        )

    response = {
        "id": data.get("id") or place_id,
        "name": (data.get("displayName") or {}).get("text"),
        "address": data.get("formattedAddress"),
        "rating": data.get("rating"),
        "price_level": data.get("priceLevel"),
        "types": data.get("types", []),
        "lat": (data.get("location") or {}).get("latitude"),
        "lng": (data.get("location") or {}).get("longitude"),
        "photo_url": [f"media/photos?photo_ref={data.get('photos', [])[0].get('name')}" if data.get("photos") else None],
        "website": website,
        "opening_hours": data.get("regularOpeningHours"),
        "current_opening_hours": data.get("currentOpeningHours"),
        "reviews": reviews,
    }

    await cache_set_json(cache_key, response, ttl_seconds=60 * 60 * 24)
    return response

@router.get("/trips/{trip_id}/places/lookup")
async def lookup_places_for_trip(
    trip_id: str,
    q: str = Query(..., min_length=2, description="Place search query, e.g. N Seoul Tower"),
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    trip = await require_trip_view_access(db, trip_id, user.id)

    destination_parts = [
        trip.destination_city,
        trip.destination_country,
    ]
    destination_text = ", ".join([p for p in destination_parts if p])

    search_query = f"{q} in {destination_text}" if destination_text else q

    cache_key = "place_lookup:v1:" + hashlib.sha256(
        f"{trip.id}|{search_query}".encode("utf-8")
    ).hexdigest()

    cached = await cache_get_json(cache_key)
    if cached is not None:
        return {
            "trip_id": trip.id,
            "query": q,
            "query_used": search_query,
            "places": cached,
            "cached": True,
        }

    try:
        data = await places_client.search_text(search_query, max_results=10)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Failed to search places: {type(e).__name__}: {str(e)}",
        )

    places = []
    for p in data.get("places", []):
        if not p.get("displayName"):
            continue

        photo_ref = None
        if p.get("photos"):
            photo_ref = p["photos"][0].get("name")

        raw_opening_hours = p.get("regularOpeningHours") or {}
        weekday_descriptions = raw_opening_hours.get("weekdayDescriptions") or []

        opening_hours_text = None
        if weekday_descriptions:
            opening_hours_text = "\n".join(weekday_descriptions)

        types = p.get("types", []) or []
        primary_type = types[0] if types else None

        places.append({
            # add-place compatible fields
            "place_id": p.get("id"),
            "place_name": p.get("displayName", {}).get("text"),
            "lat": p.get("location", {}).get("latitude"),
            "lng": p.get("location", {}).get("longitude"),
            "type": primary_type,
            "opening_hours": opening_hours_text,
            "rating": p.get("rating"),
            "activity": f"Visit {p.get('displayName', {}).get('text')}",
            "address": p.get("formattedAddress"),
            "price_level": p.get("priceLevel"),
            "reviews": [],
            "notes": None,

            # extra display fields for frontend
            "id": p.get("id"),
            "name": p.get("displayName", {}).get("text"),
            "types": types,
            "photo_url": f"media/photos?photo_ref={photo_ref}" if photo_ref else None,
            "maps_url": places_client.build_maps_link(p.get("id")) if p.get("id") else None,
        })

    await cache_set_json(cache_key, places, ttl_seconds=60 * 60)

    return {
        "trip_id": trip.id,
        "query": q,
        "query_used": search_query,
        "places": places,
        "cached": False,
    }