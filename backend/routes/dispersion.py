from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from auth.firebase import verify_token
from models.user import User
from models.club import Club
from models.shot import Shot, ShotShape
from schemas.dispersion import DispersionResponse
from services.dispersion import compute_dispersion

router = APIRouter(prefix="/api/v1/dispersion", tags=["dispersion"])


def get_current_user(db: Session, token: dict) -> User:
    user = db.query(User).filter(User.id == token["sub"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


def _build_response(club_id: str, shape: ShotShape, shots: list[Shot]) -> DispersionResponse:
    carries = [s.carry_yards for s in shots]
    offlines = [s.offline_yards for s in shots]
    result = compute_dispersion(carries, offlines)

    if result is None:
        return DispersionResponse(
            club_id=club_id,
            shot_shape=shape,
            shot_count=len(shots),
            sufficient_data=False,
        )

    return DispersionResponse(
        club_id=club_id,
        shot_shape=shape,
        shot_count=len(shots),
        sufficient_data=True,
        mean_carry=result["mean_carry"],
        mean_offline=result["mean_offline"],
        covariance_matrix=result["covariance_matrix"],
        ellipse_50=result["ellipse_50"],
        ellipse_90=result["ellipse_90"],
    )


@router.get("/{club_id}/{shot_shape}", response_model=DispersionResponse)
def get_dispersion(
    club_id: str,
    shot_shape: ShotShape,
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    user = get_current_user(db, token)
    club = db.query(Club).filter(Club.id == club_id, Club.user_id == user.id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    shots = (
        db.query(Shot)
        .filter(Shot.club_id == club_id, Shot.user_id == user.id, Shot.shot_shape == shot_shape)
        .all()
    )
    return _build_response(club_id, shot_shape, shots)


@router.get("/{club_id}", response_model=list[DispersionResponse])
def get_dispersion_all_shapes(
    club_id: str,
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    user = get_current_user(db, token)
    club = db.query(Club).filter(Club.id == club_id, Club.user_id == user.id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")

    return [
        _build_response(
            club_id,
            shape,
            db.query(Shot)
            .filter(Shot.club_id == club_id, Shot.user_id == user.id, Shot.shot_shape == shape)
            .all(),
        )
        for shape in ShotShape
    ]
