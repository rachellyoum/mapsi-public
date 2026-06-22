from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_db_user
from app.db.deps import get_db
from app.db.models import User
from app.schemas.trips import TripCreate, TripUpdate, TripOut, TripShareRequest, TripMemberOut, AddItineraryStopRequest, TrendingTripOut
from app.core.categories import THEME_CATEGORIES
from app.services.trips import (
    create_trip_service,
    list_user_trips,
    require_trip_view_access,
    update_trip_service,
    list_trip_members,
    remove_trip_member,
    share_trip,
    delete_itinerary_stop_service,
    swap_itinerary_stops_service,
    add_itinerary_stop_service,
    list_trending_trips,
    increment_trip_view_service,
    like_trip_service,
    unlike_trip_service,
    copy_trip_service,
)

router = APIRouter(prefix="/trips", tags=["trips"])


@router.post("", response_model=TripOut)
async def create_trip(
    payload: TripCreate,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await create_trip_service(db, payload, user)


@router.get("", response_model=list[TripOut])
async def list_my_trips(
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await list_user_trips(db, user.id)


@router.get("/themes")
async def get_theme_categories():
    return [{"key": k, "label": v} for k, v in THEME_CATEGORIES.items()]

@router.get("/trending", response_model=list[TrendingTripOut])
async def get_trending_trips(
    limit: int = 10,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await list_trending_trips(db, user.id, limit)


@router.post("/{trip_id}/view", response_model=TripOut)
async def increment_trip_view(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await increment_trip_view_service(db, trip_id, user.id)


@router.post("/{trip_id}/like", response_model=TripOut)
async def like_trip(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await like_trip_service(db, trip_id, user.id)


@router.delete("/{trip_id}/like", response_model=TripOut)
async def unlike_trip(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await unlike_trip_service(db, trip_id, user.id)


@router.post("/{trip_id}/copy", response_model=TripOut)
async def copy_trip(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await copy_trip_service(db, trip_id, user)


@router.get("/{trip_id}", response_model=TripOut)
async def get_trip(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await require_trip_view_access(db, trip_id, user.id)


@router.patch("/{trip_id}", response_model=TripOut)
async def update_trip(
    trip_id: str,
    payload: TripUpdate,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await update_trip_service(db, trip_id, user.id, payload)


@router.get("/{trip_id}/members", response_model=list[TripMemberOut])
async def get_trip_members(
    trip_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await list_trip_members(db, trip_id, user.id)


@router.post("/{trip_id}/share", response_model=TripMemberOut)
async def share_trip_with_user(
    trip_id: str,
    payload: TripShareRequest,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await share_trip(
        db=db,
        trip_id=trip_id,
        current_user_id=user.id,
        target_user_id=payload.user_id,
        role=payload.role,
    )


@router.delete("/{trip_id}/members/{target_user_id}", status_code=204)
async def delete_trip_member(
    trip_id: str,
    target_user_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    await remove_trip_member(db, trip_id, user.id, target_user_id)
    return Response(status_code=204)


@router.delete(
    "/{trip_id}/itinerary/days/{day_number}/stops/{stop_order}",
    response_model=TripOut,
)
async def delete_itinerary_stop(
    trip_id: str,
    day_number: int,
    stop_order: int,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await delete_itinerary_stop_service(
        db=db,
        trip_id=trip_id,
        user_id=user.id,
        day_number=day_number,
        stop_order=stop_order,
    )

@router.patch(
    "/{trip_id}/itinerary/days/{day_number}/stops/swap/{order_a}/{order_b}",
    response_model=TripOut,
)
async def swap_itinerary_stops(
    trip_id: str,
    day_number: int,
    order_a: int,
    order_b: int,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await swap_itinerary_stops_service(
        db=db,
        trip_id=trip_id,
        user_id=user.id,
        day_number=day_number,
        order_a=order_a,
        order_b=order_b,
    )

@router.post(
    "/{trip_id}/itinerary/days/{day_number}/stops",
    response_model=TripOut,
)
async def add_itinerary_stop(
    trip_id: str,
    day_number: int,
    payload: AddItineraryStopRequest,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await add_itinerary_stop_service(
        db=db,
        trip_id=trip_id,
        user_id=user.id,
        day_number=day_number,
        insert_position=payload.insert_position,
        stop_data=payload.stop.model_dump(),
    )