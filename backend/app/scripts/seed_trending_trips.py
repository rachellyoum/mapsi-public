import asyncio
import hashlib
import random
import uuid
import json
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.deps import get_db
from app.db.models import User, Trip, TripMember

from app.api.itinerary import apply_daily_opening_hours, remove_duplicate_place_names, to_compact_poi
from app.core.cache import cache_get_json, cache_set_json
from app.services.budget import apply_budget_to_itinerary
from app.services.itinerary import generate_itinerary
from app.services.pois import fetch_missing_must_visit_pois, find_matching_pois, get_pois_for_trip, normalize_pois
from app.services.transport import attach_transport_to_itinerary_dict
from app.services.trips import create_trip_service, increment_trip_view_service, like_trip_service, copy_trip_service
from app.schemas.preferences import TripPreferences
from app.schemas.trips import TripCreate


random.seed(42)


DESTINATIONS = [
    ("Tokyo", "NRT", "Japan"),
    ("Paris", "CDG", "France"),
    ("New York", "JFK", "USA"),
    ("Seoul", "ICN", "South Korea"),
    ("Rome", "ROM", "Italy"),
    ("Bangkok", "BKK", "Thailand"),
    ("Barcelona", "BCN", "Spain"),
    ("Sydney", "SYD", "Australia"),
    ("Istanbul", "IST", "Turkey"),
    ("Dubai", "DXB", "UAE"),
    ("Hong Kong", "HKG", "Hong Kong"),
    ("Los Angeles", "LAX", "USA"),
    ("Cancun", "CUN", "Mexico"),
    ("Toronto", "YYZ", "Canada"),
]


async def generate_demo_itinerary(trip: Trip):
    _, pois, _ = await get_pois_for_trip(trip, max_results=10)
    normalized_pois = normalize_pois(pois) if pois else []

    if not trip.start_datetime or not trip.end_datetime:
        raise ValueError("Trip is missing start or end datetime")

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

        return cached

    
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
    
    await cache_set_json(cache_key, itinerary_json, ttl_seconds=60 * 60 * 24)

    return itinerary_json


async def create_demo_users(db: AsyncSession, count=20) -> list[User]:
    users = []
    FIREBASE_UIDS = [
        ("UFWQ7KRtEDfbltYVUFbpeBpXENS2", "hhh@gmail.com"),
        ("o5oOa1bAiscy8izUJG7g8k7XTDt1", "cc@gmail.com"),
        ("fI3MIBHQ9aWTCVTbSkjkwQMIElo2", "bb@gmail.com"),
        ("E4CU4n3cTYYNc6B4MdciFbh5Fy33", "new2@new.com"),
        ("C60FoTm7mURjYzlWn08c7DbdbT03", "new@new.com"),
        ("rfwZL3ToMPaL5d3AcGQgDdDAPBn1", "g@gmail.com"),
        ("rm41fxuBx1PbfZLYRxbbkRXDXSY2", "ryoum@email.com"),
        ("XJ06yxjOpjab6HWbPgz3rl1gmuh2", "gg@gmail.com"),
        ("cn9eTlWKXINCCJovo1rD8XSTMXb2", "hhhh@gmail.com"),
        ("ShQWShJVfvR16EGTh3krtjRQS7g1", "yeinh0327@gmail.com"),
        ("pbkMiaHWPvYpmEJlh5H7Gi3njnP2", "test1@gmail.com"),
        ("PuSjLg9GLGU2Da7486FMqYtRNVh2", "h1@gmail.com"),
        ("gsggLz54SFSIdbjAA6nG6tFWk813", "hyi032777@gmail.com"),
        ("qB0FYn7lkjeWJDRO1YZo685UtWB3", "aa@gmail.com"),
        ("2hDr1lXzXbO3vcy3W6K2Xegeilf2", "h@gmail.com"),
        ("LdlZSRkWiBfl9mcp7IJsBio1UXW2", "hello1@gmail.com"),
        ("dPxH819VCLNEOCE9QcHZxweOEY32", "hehe@gmail.com"),
        ("meDEN87liASoS4NY6bGYnajfULx2", "hh@gmail.com"),
        ("YBdVUk6g3dQwQkxeDM6yFRMcbzh2", "babo@gmail.com"),
        ("En6cePzYHaeZcV9kRFXVvFCGf982", "hey@gmail.com"),
        ("i5zGIbh2JJXa3gy7bk8t4ulcsKh2", "test@gmail.com"),
        ("NmPCCVb5SefJn23z518VuxFGuUl2", "hi@gmail.com"),
        ("uYcUX95Cofg29dPIyNn8OCZlAW42", "hello@gmail.com"),
        ("Y231I4juhcVfDZdMxVCEQvsBAvf2", "test@test.com")
    ]

    for i in range(count):
        firebase_uid = f"demo_uid_{i}"

        # avoid duplicates if script reruns
        result = await db.execute(
            select(User).where(User.firebase_uid == firebase_uid)
        )
        existing = result.scalar_one_or_none()

        if existing:
            users.append(existing)
            continue

        user = User(
            id=str(uuid.uuid4()),
            firebase_uid=firebase_uid,
            email=f"demo{i}@test.com",
            name=f"Demo User {i}",
        )
        db.add(user)
        users.append(user)

    await db.commit()
    return users


def create_demo_payload():
    city, iata, country = random.choice(DESTINATIONS)

    start = datetime.now()
    end = start + timedelta(days=random.randint(2, 5))

    payload = TripCreate(
        origin_airport="YVR",
        destination_city=city,
        destination_iata=iata,
        destination_country=country,
        start_datetime=start,
        end_datetime=end,
        travelers_count=random.randint(1, 3),
        budget_total=random.randint(0, 3000),
        preferences=TripPreferences(
            pace=random.choice(["slow", "medium", "fast"]),
            themes=random.sample(["food", "culture", "shopping", "nature", "cafes"], k=2),
            mustVisit=[],
        ),
    )

    return payload


"""
async def create_demo_trip():

        itinerary_json=await generate_itinerary(trip, owner, db),
        status="generated",
        is_public=True,
        views_count=random.randint(100, 1000),
        likes_count=0,
        copies_count=0,
    )

    db.add(trip)

    # owner membership
    db.add(
        TripMember(
            id=str(uuid.uuid4()),
            trip_id=trip.id,
            user_id=owner.id,
            role="owner",
        )
    )

    await db.commit()
    await db.refresh(trip)

    return trip
"""

async def simulate_engagement(db: AsyncSession, trip: Trip, users: list[User]):
    # views
    view_k = random.randint(0, len(users))
    view_users = random.sample(users, k=view_k)
    for user in view_users:
        try:
            await increment_trip_view_service(db, trip.id, user.id)
        except Exception:
            pass
    
    # likes
    like_k = random.randint(0, len(view_users))
    like_users = random.sample(view_users, k=like_k)
    for user in like_users:
        try:
            await like_trip_service(db, trip.id, user.id)
        except Exception:
            pass

    # copies
    copy_k = random.randint(0, len(view_users) // 3)
    copy_users = random.sample(view_users, k=copy_k)
    for user in copy_users:
        try:
            await copy_trip_service(db, trip.id, user.id)
        except Exception:
            pass


async def run_seed(db: AsyncSession):
    print("Seeding demo users...")
    users = await create_demo_users(db)

    print("Creating trips...")
    trips = []
    for _ in range(8):
        owner = random.choice(users)
        payload = create_demo_payload()
        trip = await create_trip_service(db, payload, owner)
        itinerary = await generate_demo_itinerary(trip)

        trip.itinerary_json = itinerary
        trip.status = "generated"
        trip.is_public = True

        await db.commit()
        await db.refresh(trip)
        trips.append(trip)

    print("Simulating engagement...")
    for trip in trips:
        await simulate_engagement(db, trip, users)

    print("Done.")


async def main():
    # manually drive dependency generator
    async for db in get_db():
        await run_seed(db)
        break  # IMPORTANT: only take one session


if __name__ == "__main__":
    asyncio.run(main())