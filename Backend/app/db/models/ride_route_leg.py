from datetime import datetime

from geoalchemy2 import Geometry
from sqlalchemy import DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class RideRouteLeg(Base):
    """
    Stores one confirmed route segment of a ride.

    Example:

        Source → Stop 1 → Stop 2 → Destination

    becomes:

        Leg 1: Source → Stop 1
        Leg 2: Stop 1 → Stop 2
        Leg 3: Stop 2 → Destination

    Each leg stores its confirmed route geometry as a PostGIS
    LINESTRING using SRID 4326.

    Coordinate convention inside PostGIS:

        X = longitude
        Y = latitude
    """

    __tablename__ = "ride_route_legs"

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
    # Leg Order
    # ─────────────────────────────────────────────────────────────

    # 1, 2, 3, ...
    #
    # Example:
    #
    # Leg 1 = Source → Stop 1
    # Leg 2 = Stop 1 → Stop 2
    # Leg 3 = Stop 2 → Destination
    leg_order: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Start
    # ─────────────────────────────────────────────────────────────

    start_name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    start_lat: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    start_lng: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # End
    # ─────────────────────────────────────────────────────────────

    end_name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    end_lat: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    end_lng: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Route Metrics
    # ─────────────────────────────────────────────────────────────

    # Confirmed distance for this individual route leg.
    distance_meters: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # Confirmed duration for this individual route leg.
    duration_seconds: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # PostGIS Leg Geometry
    # ─────────────────────────────────────────────────────────────

    # Complete geometry of this individual route leg.
    #
    # PostgreSQL type:
    #
    #     geometry(LineString, 4326)
    #
    # Coordinates:
    #
    #     X = longitude
    #     Y = latitude
    #
    # Example:
    #
    #     LINESTRING(
    #         83.3950 21.8972,
    #         83.3947 21.8968,
    #         ...
    #     )
    #
    # This geometry is important for future LiftOff matching:
    #
    #     Host Leg
    #          │
    #          ├── Passenger route intersection
    #          ├── overlap calculation
    #          ├── pickup location
    #          └── drop location
    #
    # spatial_index=True enables a spatial GiST index.
    geometry = mapped_column(
        Geometry(
            geometry_type="LINESTRING",
            srid=4326,
            spatial_index=True,
        ),
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
        back_populates="route_legs",
    )