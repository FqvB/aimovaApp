import uuid
from datetime import datetime
from sqlalchemy import String, Float, Text, DateTime, Enum, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from database import Base
import enum


class ShotShape(str, enum.Enum):
    FADE = "FADE"
    DRAW = "DRAW"
    STRAIGHT = "STRAIGHT"


class Shot(Base):
    __tablename__ = "shots"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    club_id: Mapped[str] = mapped_column(String(36), ForeignKey("clubs.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id"), nullable=False)
    shot_shape: Mapped[ShotShape] = mapped_column(Enum(ShotShape), nullable=False)
    carry_yards: Mapped[float] = mapped_column(Float, nullable=False)
    offline_yards: Mapped[float] = mapped_column(Float, nullable=False)
    total_yards: Mapped[float | None] = mapped_column(Float, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    logged_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
