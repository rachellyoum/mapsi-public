"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import hashlib
#import pytz
from datetime import datetime
from app.core.deps import get_current_db_user
from app.db.deps import get_db
from app.db.models import User
from app.services.amadeus import amadeus_client
from app.core.cache import cache_get_json, cache_set_json
from app.services.trips import require_trip_view_access
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
import hashlib
from datetime import datetime
from app.core.deps import get_current_db_user
from app.db.deps import get_db
from app.db.models import User
from app.services.amadeus import amadeus_client
from app.core.cache import cache_get_json, cache_set_json
from app.services.trips import require_trip_view_access

router = APIRouter(prefix="/trips", tags=["flights"])


@router.post("/{trip_id}/flights/search")
async def search_flights_for_trip(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    trip = await require_trip_view_access(db, trip_id, user.id)

    today = datetime.now().date()

    if trip.start_datetime.date() < today:
        raise HTTPException(
            status_code=400,
            detail="Trip start date is in the past for flight search.",
        )

    if not trip.origin_airport:
        raise HTTPException(status_code=400, detail="Trip.origin_airport is required (e.g. YVR)")
    if not trip.start_datetime:
        raise HTTPException(status_code=400, detail="Trip.start_datetime is required")
    if not trip.destination_iata:
        raise HTTPException(status_code=400, detail="Trip.destination_iata is required (e.g. TYO or NRT)")

    destination_code = trip.destination_iata
    departure_date = trip.start_datetime.date().isoformat()
    return_date = trip.end_datetime.date().isoformat() if trip.end_datetime else None

    params_str = (
        f"{trip.origin_airport}|"
        f"{destination_code}|"
        f"{departure_date}|"
        f"{return_date}|"
        f"{trip.travelers_count}"
    )
    cache_key = "flights:" + hashlib.sha256(params_str.encode("utf-8")).hexdigest()

    cached = await cache_get_json(cache_key)
    if cached is not None:
        return {
            "trip_id": trip.id,
            "amadeus": cached,
            "flights": cached,
            "cached": True,
        }

    data = await amadeus_client.flight_offers_search(
        origin=trip.origin_airport,
        destination=destination_code,
        departure_date=departure_date,
        return_date=return_date,
        adults=trip.travelers_count or 1,
    )

    await cache_set_json(cache_key, data, ttl_seconds=60 * 30)

    return {
        "trip_id": trip.id,
        "amadeus": {"data": data},
        "flights": data,
        "cached": False,
    }
    
    """
    trip = await require_trip_view_access(db, trip_id, user.id)

    try:
        trip_tz_name = amadeus_client._get_timezone(trip.origin_airport)  # <-- use your airport IATA
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
    trip_tz = pytz.timezone(trip_tz_name)

    if trip.start_datetime.tzinfo is None:
        trip_start_dt = pytz.UTC.localize(trip.start_datetime)
    else:
        trip_start_dt = trip.start_datetime

    today_in_trip_tz = datetime.now(tz=trip_tz).date()
    trip_start_date = trip_start_dt.astimezone(trip_tz).date()

    if trip_start_date < today_in_trip_tz:
        raise HTTPException(
            status_code=400,
            detail="Trip start date is in the past for flight search.",
        )

    if not trip.origin_airport:
        raise HTTPException(status_code=400, detail="Trip.origin_airport is required (e.g. YVR)")
    if not trip.start_datetime:
        raise HTTPException(status_code=400, detail="Trip.start_datetime is required")
    if not trip.destination_iata:
        raise HTTPException(status_code=400, detail="Trip.destination_iata is required (e.g. TYO or NRT)")

    destination_code = trip.destination_iata
    departure_date = trip_start_date.isoformat()
    return_date = trip.end_datetime.date().isoformat() if trip.end_datetime else None

    params_str = (
        f"{trip.origin_airport}|"
        f"{destination_code}|"
        f"{departure_date}|"
        f"{return_date}|"
        f"{trip.travelers_count}"
    )
    cache_key = "flights:" + hashlib.sha256(params_str.encode("utf-8")).hexdigest()

    cached = await cache_get_json(cache_key)
    if cached is not None:
        return {
            "trip_id": trip.id,
            "flights": cached,
            "cached": True,
        }

    data = await amadeus_client.flight_offers_search(
        origin=trip.origin_airport,
        destination=destination_code,
        departure_date=departure_date,
        return_date=return_date,
        adults=trip.travelers_count or 1,
    )

    await cache_set_json(cache_key, data, ttl_seconds=60 * 30)

    return {
        "trip_id": trip.id,
        "flights": data,
        "cached": False,
    }
    """