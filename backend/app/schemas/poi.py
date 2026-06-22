from pydantic import BaseModel, Field
from typing import Optional, List

class OpeningPeriodPoint(BaseModel):
    day: int  # 0=Sunday, 1=Monday, ..., 6=Saturday
    hour: int
    minute: int


class OpeningPeriod(BaseModel):
    open: OpeningPeriodPoint
    close: Optional[OpeningPeriodPoint] = None


class OpeningHours(BaseModel):
    open_now: Optional[bool] = None
    weekday_text: List[str] = Field(default_factory=list)
    periods: List[OpeningPeriod] = Field(default_factory=list)

class ReviewAuthor(BaseModel):
    display_name: Optional[str] = None
    uri: Optional[str] = None
    photo_uri: Optional[str] = None


class PlaceReview(BaseModel):
    rating: Optional[float] = None
    text: Optional[str] = None
    publish_time: Optional[str] = None
    relative_publish_time_description: Optional[str] = None
    author: Optional[ReviewAuthor] = None

class POI(BaseModel):
    id: str
    name: str
    address: Optional[str]
    rating: Optional[float]
    price_level: Optional[str]
    types: List[str] = Field(default_factory=list)
    lat: Optional[float]
    lng: Optional[float]
    website: Optional[str] = None
    photo_refs: List[str] = Field(default_factory=list)
    opening_hours: Optional[OpeningHours] = None
    reviews: List[PlaceReview] = Field(default_factory=list)