from __future__ import annotations


# Type Grouping

FOOD_TYPES = {
    "restaurant",
    "cafe",
    "bakery",
    "bar",
    "meal_takeaway",
    "meal_delivery",
    "food",
}

ACTIVITY_TYPES = {
    "tourist_attraction",
    "museum",
    "art_gallery",
    "amusement_park",
    "zoo",
    "aquarium",
    "park",
    "natural_feature",
    "historical_landmark",
    "monument",
}

ENTERTAINMENT_TYPES = {
    "movie_theater",
    "night_club",
    "casino",
    "bowling_alley",
}


# Classify Place

def classify_place(types: list[str] | None) -> str:
    types = types or []

    if any(t in FOOD_TYPES for t in types):
        if any(t in {"cafe", "bakery"} for t in types):
            return "cafe"
        if "bar" in types:
            return "bar"
        return "restaurant"

    if any(t in ACTIVITY_TYPES for t in types):
        return "activity"

    if any(t in ENTERTAINMENT_TYPES for t in types):
        return "entertainment"

    return "other"


# ----------------------------
# ESTIMATE COST (PER PERSON)
# ----------------------------

def estimate_per_person_cost(
    price_level: int | None,
    types: list[str] | None,
) -> tuple[int, int]:
    category = classify_place(types)

    # Cafe / bakery
    if category == "cafe":
        if price_level is None:
            return (5, 15)
        return [
            (0, 8),
            (5, 12),
            (8, 18),
            (12, 25),
            (15, 35),
        ][price_level]

    # Bar
    if category == "bar":
        if price_level is None:
            return (12, 25)
        return [
            (8, 15),
            (10, 20),
            (15, 30),
            (25, 50),
            (40, 80),
        ][price_level]

    # Restaurant
    if category == "restaurant":
        if price_level is None:
            return (15, 35)
        return [
            (5, 15),
            (10, 20),
            (20, 40),
            (40, 80),
            (80, 150),
        ][price_level]

    # Activity
    if category == "activity":
        if price_level is None:
            return (0, 20)
        return [
            (0, 10),
            (5, 15),
            (10, 25),
            (20, 40),
            (30, 60),
        ][price_level]

    # Entertainment
    if category == "entertainment":
        if price_level is None:
            return (10, 30)
        return [
            (0, 15),
            (10, 25),
            (20, 40),
            (35, 70),
            (60, 120),
        ][price_level]

    # fallback
    if price_level is None:
        return (0, 20)

    return [
        (0, 10),
        (5, 15),
        (10, 25),
        (20, 50),
        (40, 90),
    ][price_level]


# ----------------------------
# APPLY TO ITINERARY
# ----------------------------

def apply_budget_to_itinerary(
    itinerary_json: dict,
    currency: str = "CAD",
) -> dict:
    total_min = 0
    total_max = 0

    for day in itinerary_json.get("days", []):
        day_min = 0
        day_max = 0

        for stop in day.get("stops", []):
            types = stop.get("types") or (
                [stop.get("type")] if stop.get("type") else []
            )

            stop_min, stop_max = estimate_per_person_cost(
                stop.get("price_level"),
                types,
            )

            stop["stop_price_level"] = {
                "currency": currency,
                "min": stop_min,
                "max": stop_max,
            }

            day_min += stop_min
            day_max += stop_max

        day["day_price_level"] = {
            "currency": currency,
            "min": day_min,
            "max": day_max,
        }

        total_min += day_min
        total_max += day_max

    trip_summary = itinerary_json.setdefault("trip_summary", {})
    trip_summary["total_price_level"] = {
        "currency": currency,
        "min": total_min,
        "max": total_max,
    }

    return itinerary_json