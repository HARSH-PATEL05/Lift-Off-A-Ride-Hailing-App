from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class RideStop(Base):
    """
    Intermediate stop/waypoint belonging to a specific ride.

    A stop is stored as a geographic point using latitude and
    longitude. The actual route geometry between stops is stored
    separately in RideRouteLeg as a PostGIS LINESTRING.
    """

    __tablename__ = "ride_stops"

    # ─────────────────────────────────────────────────────────────
    # Primary Key
    # ─────────────────────────────────────────────────────────────

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    # ─────────────────────────────────────────────────────────────
    # Ride Reference
    # ─────────────────────────────────────────────────────────────

    ride_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("rides.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ─────────────────────────────────────────────────────────────
    # Stop Information
    # ─────────────────────────────────────────────────────────────

    # Order in the host's route:
    #
    # 1 → Stop 1
    # 2 → Stop 2
    # 3 → Stop 3
    #
    # The route itself is represented by RideRouteLeg records.
    stop_order: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    stop_name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    # Geographic coordinates of the stop.
    #
    # These remain as separate latitude/longitude values because
    # the stop is a waypoint, while route matching operates on
    # the PostGIS LINESTRING stored in RideRouteLeg.
    stop_lat: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    stop_lng: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Timestamp
    # ─────────────────────────────────────────────────────────────

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Relationship
    # ─────────────────────────────────────────────────────────────

    ride = relationship(
        "Ride",
        back_populates="stops",
    )