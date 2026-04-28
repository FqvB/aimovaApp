from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session
from database import get_db
from auth.firebase import verify_token
from models.user import User
from models.club import Club
from models.shot import Shot
from schemas.club import ClubCreate, ClubUpdate, ClubReorderItem, ClubResponse, ShotCountsResponse

router = APIRouter(prefix="/api/v1/clubs", tags=["clubs"])


def get_current_user(db: Session, token: dict) -> User:
    user = db.query(User).filter(User.id == token["sub"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.get("", response_model=list[ClubResponse])
def list_clubs(db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    user = get_current_user(db, token)
    clubs = (
        db.query(Club)
        .filter(Club.user_id == user.id)
        .order_by(Club.display_order)
        .all()
    )

    raw_counts = (
        db.query(Shot.club_id, Shot.shot_shape, func.count(Shot.id).label("cnt"))
        .filter(Shot.user_id == user.id)
        .group_by(Shot.club_id, Shot.shot_shape)
        .all()
    )
    counts_by_club: dict[str, dict] = {}
    for club_id, shape, cnt in raw_counts:
        counts_by_club.setdefault(club_id, {})[shape.value] = cnt

    result = []
    for club in clubs:
        c = counts_by_club.get(club.id, {})
        response = ClubResponse.model_validate(club)
        response.shot_counts = ShotCountsResponse(
            FADE=c.get("FADE", 0),
            DRAW=c.get("DRAW", 0),
            STRAIGHT=c.get("STRAIGHT", 0),
        )
        result.append(response)
    return result


@router.post("", response_model=ClubResponse, status_code=201)
def create_club(body: ClubCreate, db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    user = get_current_user(db, token)
    club = Club(user_id=user.id, **body.model_dump())
    db.add(club)
    db.commit()
    db.refresh(club)
    return club


@router.put("/reorder", response_model=list[ClubResponse])
def reorder_clubs(body: list[ClubReorderItem], db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    user = get_current_user(db, token)
    updated = []
    for item in body:
        club = db.query(Club).filter(Club.id == item.club_id, Club.user_id == user.id).first()
        if club:
            club.display_order = item.display_order
            updated.append(club)
    db.commit()
    for club in updated:
        db.refresh(club)
    return updated


@router.put("/{club_id}", response_model=ClubResponse)
def update_club(club_id: str, body: ClubUpdate, db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    user = get_current_user(db, token)
    club = db.query(Club).filter(Club.id == club_id, Club.user_id == user.id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(club, field, value)
    db.commit()
    db.refresh(club)
    return club


@router.delete("/{club_id}", status_code=204)
def delete_club(club_id: str, db: Session = Depends(get_db), token: dict = Depends(verify_token)):
    user = get_current_user(db, token)
    club = db.query(Club).filter(Club.id == club_id, Club.user_id == user.id).first()
    if not club:
        raise HTTPException(status_code=404, detail="Club not found")
    club.is_active = False
    db.commit()
