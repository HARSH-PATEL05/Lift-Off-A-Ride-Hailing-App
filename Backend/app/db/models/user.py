from datetime import datetime

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class User(Base):
    __tablename__ = "users"

    # ─── Primary Key ───

    # Local PostgreSQL primary key
    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
    )

    # ─── Supabase Authentication ───

    # Unique UUID received from Supabase
    supabase_user_id: Mapped[str] = mapped_column(
        String,
        unique=True,
        index=True,
        nullable=False,
    )

    # ─── Basic User Information ───

    # Email received from Google / Supabase
    email: Mapped[str] = mapped_column(
        String,
        unique=True,
        index=True,
        nullable=False,
    )

    # Full name received from Google metadata
    full_name: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
    )

    # Google profile picture URL
    avatar_url: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
    )

    # ─── Contact Information ───

    # Primary phone number used by LiftOff.
    #
    # This is intentionally separate from Supabase authentication.
    # LiftOff uses this value as the user's application-level
    # contact number for the ride system.
    phone_number: Mapped[str | None] = mapped_column(
        String(20),
        unique=True,
        index=True,
        nullable=True,
    )

    # True only when phone ownership has actually been verified.
    #
    # Merely supplying a phone number during Aadhaar verification
    # does not automatically make this True.
    phone_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    # ─── Timestamps ───

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )

    # ─── Relationships ───

    user_vehicles = relationship(
        "UserVehicle",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    rides = relationship(
        "Ride",
        back_populates="host",
        cascade="all, delete-orphan",
    )