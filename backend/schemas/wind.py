from pydantic import BaseModel


class WindResponse(BaseModel):
    wind_speed_mph: float
    wind_direction_degrees: float
    wind_gusts_mph: float
    fetched_at: str
