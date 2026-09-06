from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class Ride(Base):
    """
    Represents a commute route offered by a verified host.

    - host_id         : Supabase UUID of the ride creator (references users.supabase_user_id)
    - origin/dest     : Human-readable name from search bar (+ optional lat/lng for map display)
    - departure_time  : Scheduled start time (UTC)
    - available_seats : Seats still open for passengers
    - fare_per_seat   : Host's requested fuel-share contribution per passenger (INR)
    - is_women_only   : Restrict to verified female commuters
    - democratic_consent : Existing passengers vote on new joiners
    - status          : "active" | "cancelled" | "completed"
    """

    __tablename__ = "rides"

    # ─── Primary Key ────────────────────────────────────────────────────────

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    # ─── Host Reference (Supabase UUID, not FK to keep it simple) ────────────

    host_id: Mapped[str] = mapped_column(
        String,
        index=True,
        nullable=False,
    )

    # ─── Origin ──────────────────────────────────────────────────────────────

    # Human-readable location name from the search bar
    origin_name: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    # Latitude — optional now; required once map search is wired
    origin_lat: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
    )

    # Longitude — optional now; required once map search is wired
    origin_lng: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
    )

    # ─── Destination ─────────────────────────────────────────────────────────

    destination_name: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    destination_lat: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
    )

    destination_lng: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
    )

    # ─── Ride Details ─────────────────────────────────────────────────────────

    departure_time: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
    )

    available_seats: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=3,
    )

    fare_per_seat: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        default=0.0,
    )

    # ─── Vehicle ─────────────────────────────────────────────────────────────

    vehicle_model: Mapped[Optional[str]] = mapped_column(
        String,
        nullable=True,
    )

    vehicle_number: Mapped[Optional[str]] = mapped_column(
        String,
        nullable=True,
    )

    # ─── Policies ────────────────────────────────────────────────────────────

    is_women_only: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    democratic_consent: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    # ─── Lifecycle ───────────────────────────────────────────────────────────

    # "active" | "cancelled" | "completed"
    status: Mapped[str] = mapped_column(
        String,
        default="active",
        nullable=False,
        index=True,
    )

    # ─── Timestamps ──────────────────────────────────────────────────────────

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
