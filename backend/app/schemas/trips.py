from datetime import datetime
from pydantic import BaseModel, Field, field_validator
from app.core.categories import THEME_CATEGORIES
from app.schemas.preferences import TripPreferences

class TripCreate(BaseModel):
    origin_airport: str
    destination_city: str | None = Field(default=None, examples=["Tokyo"])
    destination_iata: str
    destination_country: str | None = None

    start_datetime: datetime | None = None
    end_datetime: datetime | None = None

    travelers_count: int = 1
    budget_total: int | None = None

    preferences: TripPreferences = Field(default_factory=TripPreferences)
    

class TripUpdate(BaseModel):
    origin_airport: str | None = None
    destination_city: str | None = None
    destination_iata: str | None = None
    destination_country: str | None = None

    start_datetime: datetime | None = None
    end_datetime: datetime | None = None

    travelers_count: int | None = None
    budget_total: int | None = None

    preferences: dict | None = None
    status: str | None = None
    is_public: bool | None = None

    @field_validator("preferences")
    @classmethod
    def validate_themes(cls, v: dict | None):
        if v is None:
            return v

        themes = v.get("themes")
        if themes is None:
            return v

        if not isinstance(themes, list):
            raise ValueError("preferences.themes must be a list")

        invalid = [t for t in themes if t not in THEME_CATEGORIES]
        if invalid:
            raise ValueError(f"Invalid theme(s): {invalid}. Allowed: {list(THEME_CATEGORIES.keys())}")

        return v

class TripOut(BaseModel):
    id: str
    user_id: str
    origin_airport: str | None
    destination_city: str
    destination_iata: str 
    destination_country: str | None
    start_datetime: datetime | None = None
    end_datetime: datetime | None = None
    travelers_count: int
    budget_total: int | None
    preferences: dict
    itinerary_json: dict | None = None
    status: str
    is_public: bool = False
    views_count: int = 0
    likes_count: int = 0
    copies_count: int = 0
    source_trip_id: str | None = None

    class Config:
        from_attributes = True

class TrendingTripOut(TripOut):
    trending_score: int = 0
    is_liked_by_me: bool = False

class TripShareRequest(BaseModel):
    user_id: str
    role: str = "editor"


class TripMemberOut(BaseModel):
    id: str
    trip_id: str
    user_id: str
    role: str
    name: str | None = None
    email: str | None = None
    invited_by: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}

class ItineraryStopInput(BaseModel):
    place_name: str
    lat: float | None = None
    lng: float | None = None
    type: str | None = None
    place_id: str | None = None
    opening_hours: str | None = None
    rating: float | None = None
    activity: str
    address: str | None = None
    price_level: int | None = None
    reviews: list[dict] = Field(default_factory=list)
    notes: str | None = None


class AddItineraryStopRequest(BaseModel):
    insert_position: int
    stop: ItineraryStopInput