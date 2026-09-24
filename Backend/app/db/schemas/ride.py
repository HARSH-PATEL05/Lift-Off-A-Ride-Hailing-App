from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


# ─── Request: Host creates a ride ────────────────────────────────────────────


class RideStopCreate(BaseModel):
    """
    A host-defined intermediate waypoint on the ride route.

    Stops are route waypoints, not mandatory passenger pickup/drop points.
    """

    stop_order: int = Field(
        ...,
        ge=1,
    )

    stop_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    stop_lat: float = Field(
        ...,
        ge=-90,
        le=90,
    )

    stop_lng: float = Field(
        ...,
        ge=-180,
        le=180,
    )


class RideRouteLegCreate(BaseModel):
    """
    One calculated route segment between two consecutive waypoints.

    Geometry is the confirmed route snapshot produced by
    Module 1 → Module 2.

    The API receives geometry as latitude/longitude points.
    The backend converts these points into a PostGIS LINESTRING.
    """

    leg_order: int = Field(
        ...,
        ge=1,
    )

    # ─────────────────────────────────────────────────────────────
    # Start
    # ─────────────────────────────────────────────────────────────

    start_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    start_lat: float = Field(
        ...,
        ge=-90,
        le=90,
    )

    start_lng: float = Field(
        ...,
        ge=-180,
        le=180,
    )

    # ─────────────────────────────────────────────────────────────
    # End
    # ─────────────────────────────────────────────────────────────

    end_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    end_lat: float = Field(
        ...,
        ge=-90,
        le=90,
    )

    end_lng: float = Field(
        ...,
        ge=-180,
        le=180,
    )

    # ─────────────────────────────────────────────────────────────
    # Route Metrics
    # ─────────────────────────────────────────────────────────────

    distance_meters: float = Field(
        ...,
        ge=0,
    )

    duration_seconds: float = Field(
        ...,
        ge=0,
    )

    # ─────────────────────────────────────────────────────────────
    # Route Geometry
    # ─────────────────────────────────────────────────────────────

    # API representation:
    #
    # [
    #     {
    #         "latitude": 23.2599,
    #         "longitude": 77.4126
    #     },
    #     ...
    # ]
    #
    # The backend converts this to:
    #
    #     geometry(LineString, 4326)
    #
    # before saving it to PostgreSQL.
    geometry: list[dict[str, float]] = Field(
        ...,
        min_length=2,
    )


class RideCreateRequest(BaseModel):
    """
    Payload sent by the host when publishing a confirmed ride.

    Route, stop and vehicle information comes from the already completed
    Module 1 → Module 2 → Module 3 flow.

    IMPORTANT:
        Fare is intentionally NOT part of this request.

        The client does not calculate or submit fare.
        The backend calculates fare_per_seat using the confirmed
        ride information before saving the ride.
    """

    # ─────────────────────────────────────────────────────────────
    # Origin
    # ─────────────────────────────────────────────────────────────

    origin_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    origin_lat: float = Field(
        ...,
        ge=-90,
        le=90,
    )

    origin_lng: float = Field(
        ...,
        ge=-180,
        le=180,
    )

    # ─────────────────────────────────────────────────────────────
    # Destination
    # ─────────────────────────────────────────────────────────────

    destination_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    destination_lat: float = Field(
        ...,
        ge=-90,
        le=90,
    )

    destination_lng: float = Field(
        ...,
        ge=-180,
        le=180,
    )

    # ─────────────────────────────────────────────────────────────
    # Schedule
    # ─────────────────────────────────────────────────────────────

    # Module 1 provides the selected departure instant.
    #
    # The backend preserves this value for scheduled rides.
    # Ride Now is handled by the backend using the current time.
    departure_time: datetime = Field(...)

    ride_now: bool = Field(
        False,
        description="True when the host selected Ride Now.",
    )

    # ─────────────────────────────────────────────────────────────
    # Passenger Seats
    # ─────────────────────────────────────────────────────────────

    # Number of passenger seats offered for THIS ride.
    #
    # Backend validates:
    #
    #     available_seats <= vehicle.seating_capacity - 1
    #
    # One seat is reserved for the host.
    available_seats: int = Field(
        ...,
        ge=1,
        le=99,
        description=(
            "Passenger seats offered on LiftOff. "
            "Backend validates this against vehicle seating capacity - 1."
        ),
    )

    # ─────────────────────────────────────────────────────────────
    # Vehicle
    # ─────────────────────────────────────────────────────────────

    vehicle_id: int = Field(
        ...,
        gt=0,
        description="Verified vehicle selected by the host.",
    )

    # ─────────────────────────────────────────────────────────────
    # Confirmed Route Snapshot
    # ─────────────────────────────────────────────────────────────

    route_distance_meters: float = Field(
        ...,
        ge=0,
    )

    route_duration_seconds: float = Field(
        ...,
        ge=0,
    )

    # Complete selected route geometry.
    #
    # This remains a normal API list.
    # Backend converts it to PostGIS LINESTRING.
    route_geometry: list[dict[str, float]] = Field(
        ...,
        min_length=2,
    )

    # ─────────────────────────────────────────────────────────────
    # Intermediate Stops
    # ─────────────────────────────────────────────────────────────

    stops: list[RideStopCreate] = Field(
        default_factory=list,
    )

    # ─────────────────────────────────────────────────────────────
    # Individual Route Legs
    # ─────────────────────────────────────────────────────────────

    route_legs: list[RideRouteLegCreate] = Field(
        ...,
        min_length=1,
    )

    # ─────────────────────────────────────────────────────────────
    # Ride Policies / Preferences
    # ─────────────────────────────────────────────────────────────

    is_women_only: bool = Field(False)

    democratic_consent: bool = Field(True)

    flexible_pickup: bool = Field(False)

    allow_luggage: bool = Field(False)

    allow_pets: bool = Field(False)

    allow_music: bool = Field(False)

    is_ac: bool = Field(False)

    additional_notes: str = Field(
        default="",
        max_length=1000,
    )

    terms_accepted: bool = Field(
        ...,
        description="Host must explicitly accept the ride publishing terms.",
    )


# ─── Request: Host updates an existing ride ──────────────────────────────────


class RideUpdateRequest(BaseModel):
    """
    Complete ride snapshot used when the host edits a published ride.

    The frontend should send the complete current ride state. This keeps
    the stored route geometry, stops and route legs synchronized when any
    route-related value is changed. The backend recalculates the fare.

    Booking compatibility:
        Booking support is not implemented yet, so the current backend
        treats every ride as having no booking. The edit endpoint keeps
        the booking check in one place so the real booking state can be
        connected later without changing the frontend contract.
    """

    origin_name: str = Field(..., min_length=1, max_length=200)
    origin_lat: float = Field(..., ge=-90, le=90)
    origin_lng: float = Field(..., ge=-180, le=180)

    destination_name: str = Field(..., min_length=1, max_length=200)
    destination_lat: float = Field(..., ge=-90, le=90)
    destination_lng: float = Field(..., ge=-180, le=180)

    departure_time: datetime = Field(...)
    ride_now: bool = Field(False)

    available_seats: int = Field(
        ...,
        ge=1,
        le=99,
        description=(
            "Passenger seats offered on LiftOff. Backend validates this "
            "against vehicle seating capacity - 1."
        ),
    )

    vehicle_id: int = Field(
        ...,
        gt=0,
        description="Verified vehicle selected by the host.",
    )

    route_distance_meters: float = Field(..., ge=0)
    route_duration_seconds: float = Field(..., ge=0)
    route_geometry: list[dict[str, float]] = Field(..., min_length=2)

    stops: list[RideStopCreate] = Field(default_factory=list)
    route_legs: list[RideRouteLegCreate] = Field(..., min_length=1)

    is_women_only: bool = Field(False)
    democratic_consent: bool = Field(True)
    flexible_pickup: bool = Field(False)
    allow_luggage: bool = Field(False)
    allow_pets: bool = Field(False)
    allow_music: bool = Field(False)
    is_ac: bool = Field(False)
    additional_notes: str = Field(default="", max_length=1000)



# ─── Response: Ride Stop ─────────────────────────────────────────────────────


class RideStopResponse(BaseModel):
    id: int
    ride_id: int
    stop_order: int
    stop_name: str
    stop_lat: float
    stop_lng: float

    model_config = ConfigDict(
        from_attributes=True,
    )


# ─── Response: Route Leg ─────────────────────────────────────────────────────


class RideRouteLegResponse(BaseModel):
    id: int
    ride_id: int
    leg_order: int

    start_name: str
    start_lat: float
    start_lng: float

    end_name: str
    end_lat: float
    end_lng: float

    distance_meters: float
    duration_seconds: float

    # Returned to Flutter as latitude/longitude points.
    #
    # PostGIS remains an internal database representation.
    geometry: list[dict[str, float]]

    model_config = ConfigDict(
        from_attributes=True,
    )


# ─── Response: Ride ──────────────────────────────────────────────────────────


class RideResponse(BaseModel):
    """
    Returned after creating or fetching a ride.

    Fare is returned here because it is generated by the backend
    and stored in the rides table.
    """

    ride_id: int

    # ─────────────────────────────────────────────────────────────
    # Host
    # ─────────────────────────────────────────────────────────────

    host_id: str
    host_name: Optional[str] = None
    host_avatar: Optional[str] = None

    # ─────────────────────────────────────────────────────────────
    # Origin
    # ─────────────────────────────────────────────────────────────

    origin_name: str
    origin_lat: float
    origin_lng: float

    # ─────────────────────────────────────────────────────────────
    # Destination
    # ─────────────────────────────────────────────────────────────

    destination_name: str
    destination_lat: float
    destination_lng: float

    # ─────────────────────────────────────────────────────────────
    # Schedule
    # ─────────────────────────────────────────────────────────────

    departure_time: datetime
    ride_now: bool

    # ─────────────────────────────────────────────────────────────
    # Passenger Seats
    # ─────────────────────────────────────────────────────────────

    available_seats: int

    # ─────────────────────────────────────────────────────────────
    # Vehicle
    # ─────────────────────────────────────────────────────────────

    vehicle_id: int

    vehicle_model: Optional[str] = None
    vehicle_registration_number: Optional[str] = None
    vehicle_category: Optional[str] = None
    vehicle_subtype: Optional[str] = None
    vehicle_type_specified: Optional[str] = None
    seating_capacity: Optional[int] = None

    # ─────────────────────────────────────────────────────────────
    # Backend Fare
    # ─────────────────────────────────────────────────────────────

    # Fare for ONE passenger seat.
    #
    # This value is calculated by FastAPI/backend.
    # It is never accepted from RideCreateRequest.
    fare_per_seat: Decimal

    # ─────────────────────────────────────────────────────────────
    # Route Snapshot
    # ─────────────────────────────────────────────────────────────

    route_distance_meters: float
    route_duration_seconds: float

    # Returned as normal latitude/longitude points.
    # PostGIS is an internal storage/matching implementation.
    route_geometry: list[dict[str, float]]

    # ─────────────────────────────────────────────────────────────
    # Stops and Route Legs
    # ─────────────────────────────────────────────────────────────

    stops: list[RideStopResponse]
    route_legs: list[RideRouteLegResponse]

    # ─────────────────────────────────────────────────────────────
    # Policies
    # ─────────────────────────────────────────────────────────────

    is_women_only: bool
    democratic_consent: bool

    flexible_pickup: bool
    allow_luggage: bool
    allow_pets: bool
    allow_music: bool
    is_ac: bool
    additional_notes: str

    terms_accepted: bool

    # ─────────────────────────────────────────────────────────────
    # Lifecycle
    # ─────────────────────────────────────────────────────────────

    status: str

    # ─────────────────────────────────────────────────────────────
    # Booking / Editability
    # ─────────────────────────────────────────────────────────────

    # Booking support is not implemented yet. This remains False until
    # the future booking/matching workflow supplies the real value.
    has_booking: bool = False

    # Whether the host may edit this ride right now. The backend owns
    # this decision; Flutter should not calculate it independently.
    can_edit: bool = False
    edit_block_reason: Optional[str] = None

    # ─────────────────────────────────────────────────────────────
    # Timestamps
    # ─────────────────────────────────────────────────────────────

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(
        from_attributes=True,
    )


# ─── Response: Cancel action ─────────────────────────────────────────────────


class RideCancelResponse(BaseModel):
    ride_id: int
    status: str
    message: str