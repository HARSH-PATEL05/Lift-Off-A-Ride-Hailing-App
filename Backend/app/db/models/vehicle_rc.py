from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class VehicleRC(Base):
    __tablename__ = "vehicle_rcs"

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    vehicle_id: Mapped[int] = mapped_column(
        ForeignKey("vehicles.id"),
        nullable=False,
        unique=True,
        index=True,
    )

    vehicle = relationship(
        "Vehicle",
        back_populates="vehicle_rc",
    )

    # ─── RC Information ───

    # Never store the plaintext RC number.
    rc_encrypted: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )

    rc_last_four: Mapped[str] = mapped_column(
        String(4),
        nullable=False,
    )

    # ─── RC Verification ───

    rc_verified: Mapped[bool] = mapped_column(
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