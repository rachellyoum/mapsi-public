from fastapi import HTTPException
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm.attributes import flag_modified
from copy import deepcopy

from app.db.models import Trip, TripMember, User, TripLike
from app.schemas.trips import TripCreate, TripUpdate
from app.services.routes import get_transport_options

async def get_trip_by_id(db: AsyncSession, trip_id: str) -> Trip | None:
    result = await db.execute(
        select(Trip).where(Trip.id == trip_id)
    )
    return result.scalar_one_or_none()


async def get_trip_member(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
) -> TripMember | None:
    result = await db.execute(
        select(TripMember).where(
            TripMember.trip_id == trip_id,
            TripMember.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()


async def require_trip_view_access(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
) -> Trip:
    trip = await get_trip_by_id(db, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    member = await get_trip_member(db, trip_id, user_id)
    if not member:
        raise HTTPException(status_code=403, detail="You do not have access to this trip")

    return trip


async def require_trip_edit_access(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
) -> Trip:
    trip = await get_trip_by_id(db, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    member = await get_trip_member(db, trip_id, user_id)
    if not member or member.role not in {"owner", "editor"}:
        raise HTTPException(status_code=403, detail="You do not have permission to edit this trip")

    return trip


async def create_trip_service(
    db: AsyncSession,
    payload: TripCreate,
    user: User,
) -> Trip:
    try:
        trip = Trip(
            user_id=user.id,
            origin_airport=payload.origin_airport,
            destination_city=payload.destination_city,
            destination_iata=payload.destination_iata,
            destination_country=payload.destination_country,
            start_datetime=payload.start_datetime,
            end_datetime=payload.end_datetime,
            travelers_count=payload.travelers_count,
            budget_total=payload.budget_total,
            preferences=payload.preferences.model_dump(mode="json"),
            status="draft",
        )

        db.add(trip)
        await db.flush()

        owner_member = TripMember(
            trip_id=trip.id,
            user_id=user.id,
            role="owner",
            invited_by=user.id,
        )
        db.add(owner_member)

        await db.commit()
        await db.refresh(trip)
        return trip

    except Exception:
        await db.rollback()
        raise


async def list_user_trips(
    db: AsyncSession,
    user_id: str,
) -> list[Trip]:
    result = await db.execute(
        select(Trip)
        .join(TripMember, TripMember.trip_id == Trip.id)
        .where(TripMember.user_id == user_id)
        .order_by(Trip.created_at.desc())
    )
    return list(result.scalars().all())


async def update_trip_service(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
    payload: TripUpdate,
) -> Trip:
    trip = await require_trip_edit_access(db, trip_id, user_id)

    data = payload.model_dump(exclude_unset=True)
    
    if data.get("is_public") is True and not trip.itinerary_json:
        raise HTTPException(status_code=400, detail="Cannot publish a trip without an itinerary")
    for key, value in data.items():
        setattr(trip, key, value)

    await db.commit()
    await db.refresh(trip)
    return trip


async def share_trip(
    db: AsyncSession,
    trip_id: str,
    current_user_id: str,
    target_user_id: str,
    role: str = "editor",
) -> TripMember:
    trip = await require_trip_edit_access(db, trip_id, current_user_id)

    owner_member = await get_trip_member(db, trip_id, current_user_id)
    if not owner_member or owner_member.role != "owner":
        raise HTTPException(status_code=403, detail="Only the trip owner can share this trip")

    if role not in {"editor", "viewer"}:
        raise HTTPException(status_code=400, detail="Invalid role")

    existing = await get_trip_member(db, trip_id, target_user_id)
    if existing:
        raise HTTPException(status_code=400, detail="User already has access to this trip")

    if target_user_id == trip.user_id:
        raise HTTPException(status_code=400, detail="Owner already has access to this trip")

    member = TripMember(
        trip_id=trip_id,
        user_id=target_user_id,
        role=role,
        invited_by=current_user_id,
    )
    db.add(member)

    try:
        await db.commit()
        await db.refresh(member)
        return member
    except Exception:
        await db.rollback()
        raise


async def list_trip_members(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
) -> list[TripMember]:
    await require_trip_view_access(db, trip_id, user_id)

    result = await db.execute(
        select(TripMember, User)
        .join(User, User.id == TripMember.user_id)
        .where(TripMember.trip_id == trip_id)
        .order_by(TripMember.created_at.asc())
    )
    rows = result.all()

    return [
        {
            "id": member.id,
            "trip_id": member.trip_id,
            "user_id": member.user_id,
            "role": member.role,
            "name": user.name,
            "email": user.email,
            "invited_by": member.invited_by,
            "created_at": member.created_at,
        }
        for member, user in rows
    ]


async def remove_trip_member(
    db: AsyncSession,
    trip_id: str,
    current_user_id: str,
    target_user_id: str,
) -> None:
    trip = await get_trip_by_id(db, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    owner_member = await get_trip_member(db, trip_id, current_user_id)
    if not owner_member or owner_member.role != "owner":
        raise HTTPException(status_code=403, detail="Only the trip owner can remove members")

    member = await get_trip_member(db, trip_id, target_user_id)
    if not member:
        raise HTTPException(status_code=404, detail="Trip member not found")

    if member.role == "owner":
        raise HTTPException(status_code=400, detail="Cannot remove the trip owner")

    await db.delete(member)
    await db.commit()

# Helper functions for delete and update operations

def has_valid_lat_lng(stop: dict) -> bool:
    lat = stop.get("lat")
    lng = stop.get("lng")
    return isinstance(lat, (int, float)) and isinstance(lng, (int, float))


async def rebuild_day_travel(day: dict) -> None:
    stops = day.get("stops", [])

    for idx, stop in enumerate(stops):
        stop["order"] = idx + 1

        if idx == 0:
            stop["travel_from_previous"] = None
            continue

        prev_stop = stops[idx - 1]

        if not has_valid_lat_lng(prev_stop) or not has_valid_lat_lng(stop):
            stop["travel_from_previous"] = {
                "recommended_mode": None,
                "recommended_duration_min": None,
                "recommended_reason": "Missing coordinates",
                "distance_meters": None,
                "polyline": None,
                "options": [],
            }
            continue

        stop["travel_from_previous"] = await get_transport_options(
            origin=(prev_stop["lat"], prev_stop["lng"]),
            destination=(stop["lat"], stop["lng"]),
        )

async def delete_itinerary_stop_service(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
    day_number: int,
    stop_order: int,
) -> Trip:
    trip = await require_trip_edit_access(db, trip_id, user_id)

    itinerary = trip.itinerary_json
    if not itinerary:
        raise HTTPException(status_code=400, detail="Trip has no itinerary")

    days = itinerary.get("days")
    if not isinstance(days, list):
        raise HTTPException(status_code=400, detail="Invalid itinerary format")

    target_day = next((day for day in days if day.get("day") == day_number), None)
    if not target_day:
        raise HTTPException(status_code=404, detail="Day not found")

    stops = target_day.get("stops")
    if not isinstance(stops, list) or not stops:
        raise HTTPException(status_code=400, detail="No stops in this day")

    stop_index = stop_order - 1
    if stop_index < 0 or stop_index >= len(stops):
        raise HTTPException(status_code=404, detail="Stop not found")

    # DELETE THE STOP
    stops.pop(stop_index)

    # REBUILD TRANSPORT + ORDER
    await rebuild_day_travel(target_day)

    # IMPORTANT: force JSON update
    flag_modified(trip, "itinerary_json")

    await db.commit()
    await db.refresh(trip)
    return trip

async def swap_itinerary_stops_service(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
    day_number: int,
    order_a: int,
    order_b: int,
) -> Trip:
    trip = await require_trip_edit_access(db, trip_id, user_id)

    itinerary = trip.itinerary_json
    if not itinerary:
        raise HTTPException(status_code=400, detail="Trip has no itinerary")

    days = itinerary.get("days")
    if not isinstance(days, list):
        raise HTTPException(status_code=400, detail="Invalid itinerary format")

    target_day = next((d for d in days if d.get("day") == day_number), None)
    if not target_day:
        raise HTTPException(status_code=404, detail="Day not found")

    stops = target_day.get("stops")
    if not isinstance(stops, list) or len(stops) < 2:
        raise HTTPException(status_code=400, detail="Not enough stops to swap")

    i, j = order_a - 1, order_b - 1

    if i < 0 or i >= len(stops) or j < 0 or j >= len(stops):
        raise HTTPException(status_code=404, detail="Stop not found")

    if i == j:
        return trip  # no-op

    # SWAP
    stops[i], stops[j] = stops[j], stops[i]

    # REBUILD order + transport graph
    await rebuild_day_travel(target_day)

    flag_modified(trip, "itinerary_json")

    await db.commit()
    await db.refresh(trip)
    return trip

async def add_itinerary_stop_service(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
    day_number: int,
    insert_position: int,
    stop_data: dict,
) -> Trip:
    trip = await require_trip_edit_access(db, trip_id, user_id)

    itinerary = trip.itinerary_json
    if not itinerary:
        raise HTTPException(status_code=400, detail="Trip has no itinerary")

    days = itinerary.get("days")
    if not isinstance(days, list):
        raise HTTPException(status_code=400, detail="Invalid itinerary format")

    target_day = next((d for d in days if d.get("day") == day_number), None)
    if not target_day:
        raise HTTPException(status_code=404, detail="Day not found")

    stops = target_day.get("stops")
    if not isinstance(stops, list):
        raise HTTPException(status_code=400, detail="Invalid stops format")

    if insert_position < 1 or insert_position > len(stops) + 1:
        raise HTTPException(
            status_code=400,
            detail=f"insert_position must be between 1 and {len(stops) + 1}",
        )

    new_stop = {
        "order": insert_position,
        "place_name": stop_data.get("place_name"),
        "lat": stop_data.get("lat"),
        "lng": stop_data.get("lng"),
        "type": stop_data.get("type"),
        "place_id": stop_data.get("place_id"),
        "opening_hours": stop_data.get("opening_hours"),
        "rating": stop_data.get("rating"),
        "activity": stop_data.get("activity"),
        "address": stop_data.get("address"),
        "price_level": stop_data.get("price_level"),
        "reviews": stop_data.get("reviews", []),
        "notes": stop_data.get("notes"),
        "travel_from_previous": None,
    }

    stops.insert(insert_position - 1, new_stop)

    await rebuild_day_travel(target_day)

    flag_modified(trip, "itinerary_json")

    await db.commit()
    await db.refresh(trip)
    return trip

def compute_trending_score(trip: Trip) -> int:
    return (
        (trip.views_count or 0) * 1
        + (trip.likes_count or 0) * 3
        + (trip.copies_count or 0) * 5
    )


async def list_trending_trips(
    db: AsyncSession,
    user_id: str,
    limit: int = 10,
) -> list[dict]:
    result = await db.execute(
        select(Trip)
        .where(
            Trip.is_public == True,
            Trip.status == "generated",
            Trip.itinerary_json.is_not(None),
        )
        .order_by(
            (
                Trip.views_count * 1
                + Trip.likes_count * 3
                + Trip.copies_count * 5
            ).desc(),
            Trip.created_at.desc(),
        )
        .limit(limit)
    )

    trips = list(result.scalars().all())

    liked_result = await db.execute(
        select(TripLike.trip_id).where(
            TripLike.user_id == user_id,
            TripLike.trip_id.in_([trip.id for trip in trips]) if trips else False,
        )
    )
    liked_trip_ids = set(liked_result.scalars().all())

    return [
        {
            **trip.__dict__,
            "trending_score": compute_trending_score(trip),
            "is_liked_by_me": trip.id in liked_trip_ids,
        }
        for trip in trips
    ]


async def increment_trip_view_service(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
) -> Trip:
    trip = await get_trip_by_id(db, trip_id)

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if not trip.is_public:
        await require_trip_view_access(db, trip_id, user_id)

    trip.views_count = (trip.views_count or 0) + 1

    await db.commit()
    await db.refresh(trip)
    return trip


async def like_trip_service(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
) -> Trip:
    trip = await get_trip_by_id(db, trip_id)

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if not trip.is_public:
        raise HTTPException(status_code=403, detail="Only public trips can be liked")

    existing_result = await db.execute(
        select(TripLike).where(
            TripLike.trip_id == trip_id,
            TripLike.user_id == user_id,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if existing:
        return trip

    like = TripLike(trip_id=trip_id, user_id=user_id)
    db.add(like)

    trip.likes_count = (trip.likes_count or 0) + 1

    await db.commit()
    await db.refresh(trip)
    return trip


async def unlike_trip_service(
    db: AsyncSession,
    trip_id: str,
    user_id: str,
) -> Trip:
    trip = await get_trip_by_id(db, trip_id)

    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    existing_result = await db.execute(
        select(TripLike).where(
            TripLike.trip_id == trip_id,
            TripLike.user_id == user_id,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if not existing:
        return trip

    await db.delete(existing)
    trip.likes_count = max((trip.likes_count or 0) - 1, 0)

    await db.commit()
    await db.refresh(trip)
    return trip


async def copy_trip_service(
    db: AsyncSession,
    trip_id: str,
    user: User,
) -> Trip:
    original = await get_trip_by_id(db, trip_id)

    if not original:
        raise HTTPException(status_code=404, detail="Trip not found")

    if not original.is_public:
        raise HTTPException(status_code=403, detail="Only public trips can be copied")

    new_trip = Trip(
        user_id=user.id,
        origin_airport=original.origin_airport,
        destination_city=original.destination_city,
        destination_iata=original.destination_iata,
        destination_country=original.destination_country,
        start_datetime=original.start_datetime,
        end_datetime=original.end_datetime,
        travelers_count=original.travelers_count,
        budget_total=original.budget_total,
        preferences=deepcopy(original.preferences),
        itinerary_json=deepcopy(original.itinerary_json),
        status=original.status,
        is_public=False,
        source_trip_id=original.id,
    )

    db.add(new_trip)
    await db.flush()

    owner_member = TripMember(
        trip_id=new_trip.id,
        user_id=user.id,
        role="owner",
        invited_by=user.id,
    )
    db.add(owner_member)

    original.copies_count = (original.copies_count or 0) + 1

    await db.commit()
    await db.refresh(new_trip)
    return new_trip