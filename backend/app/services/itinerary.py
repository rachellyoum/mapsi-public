from __future__ import annotations

from datetime import datetime
import json
from openai import AsyncOpenAI
from app.core.config import settings

client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

def _n_days(start: datetime | None, end: datetime | None) -> int | None:
    if not start or not end:
        return None
    return max(1, (end.date() - start.date()).days)

async def generate_itinerary(
    destination_city: str,
    start_datetime: datetime | None,
    end_datetime: datetime | None,
    travelers_count: int,
    preferences: dict,
    pois: list[dict] | None = None,
    must_visit: list[str] | None = None,
) -> dict:
    days = _n_days(start_datetime, end_datetime)

    # Keep prompt short + deterministic
    system = ( """
               You are a travel planner.
               You MUST:
               - Only use places from the provided POIs list.
               - Prefer places with higher ratings.
               - Each stop MUST correspond to one POI.
              - Return an ordered list of stops for each day.
              - Include the exact name, rating, lat, lng, and place_id from the POIs when available.
              - If a must-visit place is provided and a matching POI exists in the provided POIs list, include it in the itinerary.
              - Prioritize must-visit places before optional places.
              - Do NOT invent a must-visit place if it is not present in the POIs list.
               
               If POIs are insufficient, you may reuse them but do not hallucinate new ones.
               Return ONLY valid JSON matching the schema.
              
              Daily planning rules:
                - Build a realistic FULL-DAY schedule for each day.
                - Each day should usually contain 4 to 6 stops if enough POIs are available.
                - Include food stops when possible, especially lunch and/or dinner, using restaurant/cafe POIs near the other stops.
                - Group stops that are geographically close together to reduce transport time.
                - Avoid sending the user back and forth across the city in the same day.
                - Prefer a route where stops in the same day are clustered by nearby lat/lng.
                - Start with lighter morning activities, then midday/lunch, then afternoon attractions, then dinner/evening when appropriate.
                - If POIs are limited, reuse good POIs only when necessary, but still try to make the day feel complete (Only reuse when necessary).
                - If there are not enough POIs for 4 to 6 stops, return as many strong relevant stops as possible without hallucinating.

            """
    )

    schema = {
        "trip_summary": {
            "destination": "string",
            "days": "number|null",
            "vibe": "string|null",
        },
        "days": [
            {
                "day": "number",
                "title": "string",
                "stops": [
                    {
                        "order": "number",
                        "place_name": "string",
                        "lat": "number|null",
                        "lng": "number|null",
                        "type": "string|null",
                        "place_id": "string|null",
                        "opening_hours": "string|null",
                        "rating": "number|null",
                        "activity": "string",
                        "address": "string|null",
                        "price_level": "number|null",
                        "reviews": [
                            {
                                "rating": "number|null",
                                "text": "string|null",
                                "publish_time": "string|null",
                                "relative_publish_time_description": "string|null",
                                "author": {
                                    "display_name": "string|null",
                                    "uri": "string|null",
                                    "photo_uri": "string|null",
                                },  
                            }
                        ],
                        "notes": "string|null",
                    }
                ],
            }
        ],
        "tips": ["string"],
    }
    # normalize must_visit (supports both strings and objects)
    normalized_must_visit = []

    for item in must_visit or []:
        if isinstance(item, str):
            normalized_must_visit.append(item)
        elif isinstance(item, dict):
            name = item.get("place_name") or item.get("name")
            if name:
                normalized_must_visit.append(name)

    user = {
        "destination_city": destination_city,
        "start_datetime": start_datetime.date().isoformat() if start_datetime else None,
        "end_datetime": end_datetime.date().isoformat() if end_datetime else None,
        "travelers_count": travelers_count,
        "must_visit": normalized_must_visit,
        "preferences": {
            **preferences,
            "selection_rules": [
            "prioritize rating >= 4.2",
            "avoid duplicates unless necessary",
            "mix categories (food, attractions, etc.)",
            "cluster places that are geographically close using lat/lng",
            "minimize transport time within each day",
            "include meal stops near activity stops when possible",
            "aim for 4 to 6 stops per day if enough POIs are available",
            "include must-visit places if matching POIs exist",
            ]
        },
        "pois": pois,
        "required_json_schema": schema,
    }

    resp = await client.chat.completions.create(
        model="gpt-4.1-mini",
        temperature=0.4,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": f"Generate a {days}-day itinerary. Use following structured input: {user}."},
        ],
    )

    content = resp.choices[0].message.content
    return json.loads(content)
