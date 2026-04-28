from pydantic import BaseModel
from models.shot import ShotShape


class EllipseParams(BaseModel):
    semi_major: float
    semi_minor: float
    rotation_degrees: float


class DispersionResponse(BaseModel):
    club_id: str
    shot_shape: ShotShape
    shot_count: int
    sufficient_data: bool
    mean_carry: float | None = None
    mean_offline: float | None = None
    covariance_matrix: list[list[float]] | None = None
    ellipse_50: EllipseParams | None = None
    ellipse_90: EllipseParams | None = None
