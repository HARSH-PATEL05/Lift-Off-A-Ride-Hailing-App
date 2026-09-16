from datetime import datetime

from geoalchemy2 import Geometry
from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class Ride(Base):
    """
    Represents a commute ride offered by a host.

    Architecture:

        User
          │
          └── Ride
                │
                ├── Vehicle
                ├── RideStops
                └── RideRouteLegs

    Vehicle information is not duplicated inside the ride.
    The ride references the verified vehicle through vehicle_id.

    Route information is stored as a snapshot because the host
    has already selected and confirmed the route in Modules 1 and 2.

    The complete confirmed route is stored as a PostGIS LINESTRING
    using SRID 4326.

    Fare is calculated by the backend and stored as fare_per_seat.
    """

    __tablename__ = "rides"

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
    # Host
    # ─────────────────────────────────────────────────────────────

    # Local users.id, not the Supabase UUID.
    host_user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    # ─────────────────────────────────────────────────────────────
    # Origin
    # ─────────────────────────────────────────────────────────────

    origin_name: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    origin_lat: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    origin_lng: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Destination
    # ─────────────────────────────────────────────────────────────

    destination_name: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    destination_lat: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    destination_lng: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Schedule
    # ─────────────────────────────────────────────────────────────

    # PostgreSQL TIMESTAMP WITH TIME ZONE.
    #
    # The frontend sends the selected departure instant.
    # Backend normalizes it to UTC before saving.
    departure_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )

    ride_now: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Passenger Seats
    # ─────────────────────────────────────────────────────────────

    # Passenger seats offered for THIS ride.
    #
    # Maximum allowed by backend:
    #
    #     vehicle.seating_capacity - 1
    #
    # One seat is reserved for the host.
    available_seats: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Vehicle
    # ─────────────────────────────────────────────────────────────

    # References the normalized verified vehicle.
    vehicle_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("vehicles.id"),
        nullable=False,
        index=True,
    )

    # ─────────────────────────────────────────────────────────────
    # Fare
    # ─────────────────────────────────────────────────────────────

    # Fare for ONE passenger seat.
    #
    # IMPORTANT:
    # This value is calculated by the backend fare service.
    # It is NOT accepted from the frontend.
    #
    # NUMERIC(10,2) is used instead of Float because this is
    # monetary data and should not use floating-point storage.
    fare_per_seat: Mapped[float] = mapped_column(
        Numeric(10, 2),
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Complete Route Snapshot
    # ─────────────────────────────────────────────────────────────

    # Total confirmed route distance in meters.
    route_distance_meters: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # Total confirmed route duration in seconds.
    route_duration_seconds: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # PostGIS Route Geometry
    # ─────────────────────────────────────────────────────────────

    # Complete selected route geometry.
    #
    # Stored in PostgreSQL as:
    #
    #     geometry(LineString, 4326)
    #
    # Coordinate order:
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
    # SRID 4326 = WGS 84 geographic coordinate system.
    #
    # spatial_index=True allows GeoAlchemy2 to create/use a
    # spatial GiST index for future route matching queries.
    route_geometry = mapped_column(
        Geometry(
            geometry_type="LINESTRING",
            srid=4326,
            spatial_index=True,
        ),
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Ride Policies / Preferences
    # ─────────────────────────────────────────────────────────────

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

    flexible_pickup: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    allow_luggage: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    allow_pets: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    allow_music: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    is_ac: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    additional_notes: Mapped[str] = mapped_column(
        Text,
        default="",
        nullable=False,
    )

    terms_accepted: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Lifecycle
    # ─────────────────────────────────────────────────────────────

    # active | cancelled | completed
    status: Mapped[str] = mapped_column(
        String(30),
        default="active",
        nullable=False,
        index=True,
    )

    # ─────────────────────────────────────────────────────────────
    # Timestamps
    # ─────────────────────────────────────────────────────────────

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )

    # ─────────────────────────────────────────────────────────────
    # Relationships
    # ─────────────────────────────────────────────────────────────

    host = relationship(
        "User",
        back_populates="rides",
    )

    vehicle = relationship(
        "Vehicle",
        back_populates="rides",
    )

    stops = relationship(
        "RideStop",
        back_populates="ride",
        cascade="all, delete-orphan",
        order_by="RideStop.stop_order",
    )

    route_legs = relationship(
        "RideRouteLeg",
        back_populates="ride",
        cascade="all, delete-orphan",
        order_by="RideRouteLeg.leg_order",
    )