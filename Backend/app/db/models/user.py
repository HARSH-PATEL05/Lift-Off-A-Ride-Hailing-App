from datetime import datetime

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

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