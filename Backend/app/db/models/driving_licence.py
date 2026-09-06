from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class DrivingLicence(Base):
    __tablename__ = "driving_licences"

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        unique=True,
        nullable=False,
        index=True,
    )

    user = relationship(
        "User",
        backref="driving_licence",
    )

    # ─── Driving Licence Information ───

    dl_encrypted: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )

    dl_last_four: Mapped[str] = mapped_column(
        String(4),
        nullable=False,
    )

    # ─── Driving Licence Verification ───

    dl_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    verification_reference: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
    )

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