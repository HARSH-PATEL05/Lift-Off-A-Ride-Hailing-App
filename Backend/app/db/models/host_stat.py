from datetime import datetime
from sqlalchemy import DateTime, Float, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.database import Base


class HostStat(Base):
    """
    Stores aggregated host reputation, ride history,
    behavioural rating, and community impact metrics.
    """

    __tablename__ = "host_stats"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        unique=True,
        nullable=False,
        index=True,
    )

    # ─── Host Reputation ───────────────────────────────────────

    # Overall rating given by passengers.
    rating: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )

    # Behavioural rating based on factors such as:
    # punctuality, cancellations, conduct, reliability, etc.
    behavioural_rating: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )

    # ─── Ride History ─────────────────────────────────────────

    shared_commutes_count: Mapped[int] = mapped_column(
            Integer,
            default=0,
            nullable=False,
        )
    # Number of rides successfully completed by the host.
    completed_rides_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    # ─── Community Impact ─────────────────────────────────────

    fuel_recovered_inr: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )

    co2_saved_kg: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )

    # ─── Timestamp ────────────────────────────────────────────

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )

    # ─── Relationship ─────────────────────────────────────────

    user = relationship(
        "User",
        backref="host_stat",
    )