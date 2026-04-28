from pydantic import BaseModel
from datetime import datetime
from models.shot import ShotShape


class ShotCreate(BaseModel):
    shot_shape: ShotShape
    carry_yards: float
    offline_yards: float
    total_yards: float | None = None
    notes: str | None = None
    logged_at: datetime


class ShotResponse(BaseModel):
    id: str
    club_id: str
    user_id: str
    shot_shape: ShotShape
    carry_yards: float
    offline_yards: float
    total_yards: float | None
    notes: str | None
    logged_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}
