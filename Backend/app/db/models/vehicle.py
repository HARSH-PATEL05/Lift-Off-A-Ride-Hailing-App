from datetime import datetime

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class Vehicle(Base):
    __tablename__ = "vehicles"

    # ─── Primary Key ────────────────────────────────────────────────────────

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    # ─── Vehicle Identity ───────────────────────────────────────────────────

    # Full vehicle registration number.
    # This is displayable information and represents
    # the verified vehicle identity.
    registration_number: Mapped[str] = mapped_column(
        String(20),
        unique=True,
        index=True,
        nullable=False,
    )

    # ─── Basic Vehicle Information ──────────────────────────────────────────

    vehicle_model: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    vehicle_color: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )

    # ─── Vehicle Classification ─────────────────────────────────────────────

    # Main vehicle category.
    #
    # Supported categories:
    #
    #   2_WHEELER
    #   3_WHEELER
    #   4_WHEELER
    #   COMMERCIAL_VEHICLE
    #   OTHER
    #
    # Stored as String instead of a database enum so that
    # categories can be extended later without requiring
    # an enum migration.
    vehicle_category: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
    )

    # Vehicle subtype within the selected category.
    #
    # Examples:
    #
    # 2_WHEELER:
    #   BIKE
    #   SCOOTY
    #
    # 3_WHEELER:
    #   AUTO
    #   E_RICKSHAW
    #   TOTO
    #
    # 4_WHEELER:
    #   FIVE_SEATER
    #   SEVEN_SEATER
    #
    # COMMERCIAL_VEHICLE:
    #   TRUCK_TRAILER
    #   PICKUP
    #   TAMPO
    #   VAN
    #   OTHER
    #
    # OTHER:
    #   OTHER
    vehicle_subtype: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )

    # If the host selects an "Other" vehicle type,
    # the actual vehicle type is stored here.
    #
    # For normal predefined vehicle types this remains NULL.
    vehicle_type_specified: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )

    # ─── Vehicle Capacity ───────────────────────────────────────────────────

    # Total passenger/seating capacity of the verified vehicle.
    #
    # This is a permanent property of the vehicle and is
    # supplied during the vehicle verification process.
    seating_capacity: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    # ─── Relationships ──────────────────────────────────────────────────────

    user_vehicles = relationship(
        "UserVehicle",
        back_populates="vehicle",
        cascade="all, delete-orphan",
    )

    vehicle_rc = relationship(
        "VehicleRC",
        back_populates="vehicle",
        uselist=False,
        cascade="all, delete-orphan",
    )

    rides = relationship(
        "Ride",
        back_populates="vehicle",
    )

    # ─── Timestamps ─────────────────────────────────────────────────────────

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