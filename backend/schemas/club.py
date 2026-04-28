from pydantic import BaseModel
from datetime import datetime
from models.club import ClubType


class ClubCreate(BaseModel):
    name: str
    club_type: ClubType
    loft_degrees: float | None = None
    display_order: int = 0


class ClubUpdate(BaseModel):
    name: str | None = None
    club_type: ClubType | None = None
    loft_degrees: float | None = None
    display_order: int | None = None
    is_active: bool | None = None


class ClubReorderItem(BaseModel):
    club_id: str
    display_order: int


class ShotCountsResponse(BaseModel):
    FADE: int = 0
    DRAW: int = 0
    STRAIGHT: int = 0


class ClubResponse(BaseModel):
    id: str
    user_id: str
    name: str
    club_type: ClubType
    loft_degrees: float | None
    display_order: int
    is_active: bool
    shot_counts: ShotCountsResponse = ShotCountsResponse()
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
