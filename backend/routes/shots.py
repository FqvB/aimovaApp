from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from database import get_db
from auth.firebase import verify_token
from models.user import User
from models.club import Club
from models.shot import Shot, ShotShape
from schemas.shot import ShotCreate, ShotResponse

router = APIRouter(tags=["shots"])


def get_current_user(db: Session, token: dict) -> User:
    user = db.query(User).filter(User.id == token["sub"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get("/api/v1/clubs/{club_id}/shots", response_model=list[ShotResponse])
def list_shots(
    club_id: str,
    shape: ShotShape | None = Query(None),
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    user = get_current_user(db, token)
    club = db.query(Club).filter(Club.id == club_id, Club.user_id == user.id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")
    q = db.query(Shot).filter(Shot.club_id == club_id, Shot.user_id == user.id)
    if shape:
        q = q.filter(Shot.shot_shape == shape)
    return q.order_by(Shot.logged_at.desc()).all()


@router.post("/api/v1/clubs/{club_id}/shots", response_model=ShotResponse, status_code=201)
def create_shot(
    club_id: str,
    body: ShotCreate,
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    user = get_current_user(db, token)
    club = db.query(Club).filter(Club.id == club_id, Club.user_id == user.id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")
    shot = Shot(club_id=club_id, user_id=user.id, **body.model_dump())
    db.add(shot)
    db.commit()
    db.refresh(shot)
    return shot


@router.delete("/api/v1/shots/{shot_id}", status_code=204)
def delete_shot(
    shot_id: str,
    db: Session = Depends(get_db),
    token: dict = Depends(verify_token),
):
    user = get_current_user(db, token)
    shot = db.query(Shot).filter(Shot.id == shot_id, Shot.user_id == user.id).first()
    if not shot:
        raise HTTPException(status_code=404, detail="Shot not found")
    db.delete(shot)
    db.commit()
