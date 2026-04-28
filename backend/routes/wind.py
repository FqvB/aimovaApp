from fastapi import APIRouter, Depends, Query, HTTPException
import httpx
from datetime import datetime, timezone
from auth.firebase import verify_token
from schemas.wind import WindResponse

router = APIRouter(prefix="/api/v1", tags=["wind"])

_cache: dict[str, tuple[datetime, WindResponse]] = {}
_CACHE_TTL_SECONDS = 600


def _bucket(lat: float, lon: float) -> str:
    return f"{round(lat, 2)},{round(lon, 2)}"


@router.get("/wind", response_model=WindResponse)
async def get_wind(
    lat: float = Query(...),
    lon: float = Query(...),
    _user: dict = Depends(verify_token),
):
    key = _bucket(lat, lon)
    now = datetime.now(timezone.utc)

    if key in _cache:
        cached_at, cached_response = _cache[key]
        if (now - cached_at).total_seconds() < _CACHE_TTL_SECONDS:
            return cached_response

    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={lat}&longitude={lon}"
        "&current=wind_speed_10m,wind_direction_10m,wind_gusts_10m"
        "&wind_speed_unit=ms"
    )
    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(url, timeout=10.0)
            resp.raise_for_status()
        except Exception as exc:
            raise HTTPException(status_code=503, detail=f"Wind data unavailable: {exc}")

    data = resp.json()
    current = data.get("current", {})
    speed_ms = float(current.get("wind_speed_10m", 0.0))
    direction = float(current.get("wind_direction_10m", 0.0))
    gusts_ms = float(current.get("wind_gusts_10m", 0.0))

    result = WindResponse(
        wind_speed_mph=round(speed_ms * 2.23694, 2),
        wind_direction_degrees=direction,
        wind_gusts_mph=round(gusts_ms * 2.23694, 2),
        fetched_at=now.strftime("%Y-%m-%dT%H:%M:%S"),
    )
    _cache[key] = (now, result)
    return result
