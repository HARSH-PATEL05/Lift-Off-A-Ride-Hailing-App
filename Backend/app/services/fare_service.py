from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP


# ─────────────────────────────────────────────────────────────
# Temporary pricing policy
# ─────────────────────────────────────────────────────────────
#
# These values are only for the current working implementation.
# The final LiftOff fare formula will be added later.
#

BASE_FARE = Decimal("20.00")
RATE_PER_KM = Decimal("8.00")
RATE_PER_MINUTE = Decimal("0.50")


# ─────────────────────────────────────────────────────────────
# Fare Input
# ─────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class FareInput:
    """
    Complete pricing input structure for LiftOff.

    The current fare formula only uses distance and duration.
    The remaining fields are intentionally passed through now
    so the final pricing formula can use them later without
    changing the fare-engine interface.
    """

    # ─────────────────────────────────────────
    # Route
    # ─────────────────────────────────────────

    distance_meters: float
    duration_seconds: float

    number_of_stops: int
    number_of_legs: int

    # ─────────────────────────────────────────
    # Timing
    # ─────────────────────────────────────────

    departure_time: datetime
    ride_now: bool

    # ─────────────────────────────────────────
    # Vehicle
    # ─────────────────────────────────────────

    vehicle_category: str
    vehicle_subtype: str
    vehicle_type_specified: str | None

    seating_capacity: int
    available_seats: int

    # ─────────────────────────────────────────
    # Ride Preferences
    # ─────────────────────────────────────────

    is_ac: bool
    flexible_pickup: bool
    allow_luggage: bool
    allow_pets: bool
    allow_music: bool
    is_women_only: bool

    # ─────────────────────────────────────────
    # Passenger / Booking
    # ─────────────────────────────────────────

    passenger_count: int
    requested_seats: int

    # ─────────────────────────────────────────
    # Booking Context
    # ─────────────────────────────────────────

    booking_time: datetime | None = None


# ─────────────────────────────────────────────────────────────
# Fare Calculation
# ─────────────────────────────────────────────────────────────


def calculate_fare_per_seat(
    data: FareInput,
) -> Decimal:
    """
    Calculate fare per passenger seat.

    CURRENT IMPLEMENTATION
    ----------------------
    This is only a temporary working formula:

        Fare =
            Base Fare
            + Distance (km) × Rate per km
            + Duration (minutes) × Rate per minute

    All other FareInput fields are already available to this
    function and will be used when the final LiftOff pricing
    formula is implemented.
    """

    # ─────────────────────────────────────────
    # Basic validation
    # ─────────────────────────────────────────

    if data.distance_meters < 0:
        raise ValueError(
            "Distance cannot be negative."
        )

    if data.duration_seconds < 0:
        raise ValueError(
            "Duration cannot be negative."
        )

    if data.number_of_stops < 0:
        raise ValueError(
            "Number of stops cannot be negative."
        )

    if data.number_of_legs < 1:
        raise ValueError(
            "Number of route legs must be at least 1."
        )

    if data.seating_capacity < 1:
        raise ValueError(
            "Seating capacity must be at least 1."
        )

    if data.available_seats < 1:
        raise ValueError(
            "Available seats must be at least 1."
        )

    # During ride creation there are no passengers yet.
    # Therefore passenger_count = 0 is valid.
    if data.passenger_count < 0:
        raise ValueError(
            "Passenger count cannot be negative."
        )

    # During ride creation there is no booking request yet.
    # Therefore requested_seats = 0 is valid.
    if data.requested_seats < 0:
        raise ValueError(
            "Requested seats cannot be negative."
        )

    # ─────────────────────────────────────────
    # Convert route metrics
    # ─────────────────────────────────────────

    distance_km = (
        Decimal(str(data.distance_meters))
        / Decimal("1000")
    )

    duration_minutes = (
        Decimal(str(data.duration_seconds))
        / Decimal("60")
    )

    # ─────────────────────────────────────────
    # TEMPORARY FARE FORMULA
    # ─────────────────────────────────────────
    #
    # Currently only distance and duration are used.
    #
    # The remaining FareInput fields are intentionally
    # preserved for the final pricing algorithm.
    #

    fare = (
        BASE_FARE
        + distance_km * RATE_PER_KM
        + duration_minutes * RATE_PER_MINUTE
    )

    # ─────────────────────────────────────────
    # Monetary rounding
    # ─────────────────────────────────────────

    return fare.quantize(
        Decimal("0.01"),
        rounding=ROUND_HALF_UP,
    )