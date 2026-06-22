from __future__ import annotations

from typing import Literal, Optional
from pydantic import BaseModel, Field

TransportMode = Literal["DRIVE", "TRANSIT", "WALK", "BICYCLE"]

class TransportOption(BaseModel):
    mode: TransportMode
    duration_min: Optional[int] = None
    distance_meters: Optional[int] = None
    available: bool = True
    reason_unavailable: Optional[str] = None
    polyline: Optional[str] = None

class TravelFromPrevious(BaseModel):
    recommended_mode: TransportMode
    recommended_duration_min: int
    recommended_reason: Optional[str] = None
    options: list[TransportOption] = Field(default_factory=list)