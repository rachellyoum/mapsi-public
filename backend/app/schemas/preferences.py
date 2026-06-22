from enum import Enum
from typing import Any
from pydantic import BaseModel, Field, field_validator
from app.core.categories import THEME_CATEGORIES

class PaceEnum(str, Enum):
    slow = "slow"
    medium = "medium"
    fast = "fast"

class TransportEnum(str, Enum):
    car = "car"
    public = "public"
    walk = "walk"
class MustVisitPlace(BaseModel):
    place_id: str | None = None
    place_name: str
    lat: float | None = None
    lng: float | None = None
    address: str | None = None
    rating: float | None = None
    type: str | None = None

class TripPreferences(BaseModel):
    pace: PaceEnum | None = None
    themes: list[str] = Field(default_factory=list)

    # accepts new object format
    mustVisit: list[MustVisitPlace] = Field(default_factory=list)

    @field_validator("themes")
    @classmethod
    def validate_themes(cls, v):
        if not isinstance(v, list):
            raise ValueError("themes must be a list")

        invalid = [t for t in v if t not in THEME_CATEGORIES]
        if invalid:
            raise ValueError(
                f"Invalid theme(s): {invalid}. Allowed: {list(THEME_CATEGORIES.keys())}"
            )
        return v

    @field_validator("mustVisit", mode="before")
    @classmethod
    def normalize_must_visit(cls, v: Any):
        if not v:
            return []

        if not isinstance(v, list):
            raise ValueError("mustVisit must be a list")

        normalized = []

        for item in v:
            # backwards-compatible old format: ["N Seoul Tower"]
            if isinstance(item, str):
                normalized.append({
                    "place_name": item,
                })

            elif isinstance(item, dict):
                place_name = item.get("place_name") or item.get("name")
                if not place_name:
                    raise ValueError("Each mustVisit object must include place_name or name")

                normalized.append({
                    "place_id": item.get("place_id") or item.get("id"),
                    "place_name": place_name,
                    "lat": item.get("lat"),
                    "lng": item.get("lng"),
                    "address": item.get("address"),
                    "rating": item.get("rating"),
                    "type": item.get("type"),
                })

            else:
                raise ValueError("Each mustVisit item must be a string or object")

        return normalized