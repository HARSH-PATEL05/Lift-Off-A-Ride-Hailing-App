from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


# ═════════════════════════════════════════════════════════════════════════════
# COMMON VALIDATION / NESTED SCHEMAS
# ═════════════════════════════════════════════════════════════════════════════


class GeoPoint(BaseModel):
    """
    Standard API representation of a geographic coordinate.

    API:
        latitude / longitude

    PostGIS internally:
        X = longitude
        Y = latitude
    """

    latitude: float = Field(
        ...,
        ge=-90.0,
        le=90.0,
    )

    longitude: float = Field(
        ...,
        ge=-180.0,
        le=180.0,
    )


# ═════════════════════════════════════════════════════════════════════════════
# REQUEST: HOST CREATES A RIDE
# ═════════════════════════════════════════════════════════════════════════════


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

    # ─── Start ───────────────────────────────────────────────────────────────

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

    # ─── End ─────────────────────────────────────────────────────────────────

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

    # ─── Route Metrics ──────────────────────────────────────────────────────

    distance_meters: float = Field(
        ...,
        ge=0,
    )

    duration_seconds: float = Field(
        ...,
        ge=0,
    )

    # ─── Route Geometry ─────────────────────────────────────────────────────

    geometry: list[GeoPoint] = Field(
        ...,
        min_length=2,
    )


class RideCreateRequest(BaseModel):
    """
    Payload sent by the host when publishing a confirmed ride.

    Fare is intentionally NOT part of this request.

    The backend calculates fare_per_seat using the confirmed
    ride information before saving the ride.
    """

    # ─── Origin ─────────────────────────────────────────────────────────────

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

    # ─── Destination ────────────────────────────────────────────────────────

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

    # ─── Schedule ───────────────────────────────────────────────────────────

    departure_time: datetime = Field(...)

    ride_now: bool = Field(
        False,
        description="True when the host selected Ride Now.",
    )

    # ─── Passenger Seats ────────────────────────────────────────────────────

    available_seats: int = Field(
        ...,
        ge=1,
        le=99,
        description=(
            "Passenger seats offered on LiftOff. "
            "Backend validates this against vehicle seating capacity - 1."
        ),
    )

    # ─── Vehicle ─────────────────────────────────────────────────────────────

    vehicle_id: int = Field(
        ...,
        gt=0,
        description="Verified vehicle selected by the host.",
    )

    # ─── Confirmed Route Snapshot ───────────────────────────────────────────

    route_distance_meters: float = Field(
        ...,
        ge=0,
    )

    route_duration_seconds: float = Field(
        ...,
        ge=0,
    )

    route_geometry: list[GeoPoint] = Field(
        ...,
        min_length=2,
    )

    # ─── Intermediate Stops ─────────────────────────────────────────────────

    stops: list[RideStopCreate] = Field(
        default_factory=list,
    )

    # ─── Individual Route Legs ──────────────────────────────────────────────

    route_legs: list[RideRouteLegCreate] = Field(
        ...,
        min_length=1,
    )

    # ─── Ride Policies / Preferences ────────────────────────────────────────

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


# ═════════════════════════════════════════════════════════════════════════════
# REQUEST: HOST UPDATES AN EXISTING RIDE
# ═════════════════════════════════════════════════════════════════════════════


class RideUpdateRequest(BaseModel):
    """
    Complete ride snapshot used when the host edits a published ride.

    The frontend sends the complete current ride state.
    The backend recalculates the fare.
    """

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

    departure_time: datetime = Field(...)

    ride_now: bool = Field(False)

    available_seats: int = Field(
        ...,
        ge=1,
        le=99,
        description=(
            "Passenger seats offered on LiftOff. "
            "Backend validates this against vehicle seating capacity - 1."
        ),
    )

    vehicle_id: int = Field(
        ...,
        gt=0,
        description="Verified vehicle selected by the host.",
    )

    route_distance_meters: float = Field(
        ...,
        ge=0,
    )

    route_duration_seconds: float = Field(
        ...,
        ge=0,
    )

    route_geometry: list[GeoPoint] = Field(
        ...,
        min_length=2,
    )

    stops: list[RideStopCreate] = Field(
        default_factory=list,
    )

    route_legs: list[RideRouteLegCreate] = Field(
        ...,
        min_length=1,
    )

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


# ═════════════════════════════════════════════════════════════════════════════
# RESPONSE: RIDE STOP
# ═════════════════════════════════════════════════════════════════════════════


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


# ═════════════════════════════════════════════════════════════════════════════
# RESPONSE: ROUTE LEG
# ═════════════════════════════════════════════════════════════════════════════


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
    geometry: list[GeoPoint] = Field(
        default_factory=list,
    )

    model_config = ConfigDict(
        from_attributes=True,
    )


# ═════════════════════════════════════════════════════════════════════════════
# RESPONSE: HOST RIDE
# ═════════════════════════════════════════════════════════════════════════════


class RideResponse(BaseModel):
    """
    Response used by the host's own ride APIs.

    IMPORTANT:
        This remains separate from the Community Ride responses.

    Registration number is retained here because the existing host-side
    ride functionality may depend on it.

    Community APIs must NOT use this response.
    """

    ride_id: int

    # ─── Host ───────────────────────────────────────────────────────────────

    host_id: str
    host_name: Optional[str] = None
    host_avatar: Optional[str] = None

    # ─── Origin ─────────────────────────────────────────────────────────────

    origin_name: str
    origin_lat: float
    origin_lng: float

    # ─── Destination ────────────────────────────────────────────────────────

    destination_name: str
    destination_lat: float
    destination_lng: float

    # ─── Schedule ───────────────────────────────────────────────────────────

    departure_time: datetime
    ride_now: bool

    # ─── Passenger Seats ────────────────────────────────────────────────────

    available_seats: int

    # ─── Vehicle ────────────────────────────────────────────────────────────

    vehicle_id: int

    vehicle_model: Optional[str] = None

    # Existing host-side field.
    vehicle_registration_number: Optional[str] = None

    vehicle_category: Optional[str] = None
    vehicle_subtype: Optional[str] = None
    vehicle_type_specified: Optional[str] = None
    seating_capacity: Optional[int] = None

    # ─── Backend Fare ───────────────────────────────────────────────────────

    fare_per_seat: Decimal = Field(
        ...,
        ge=Decimal("0.00"),
        decimal_places=2,
        max_digits=10,
    )

    # ─── Route Snapshot ─────────────────────────────────────────────────────

    route_distance_meters: float
    route_duration_seconds: float

    route_geometry: list[GeoPoint] = Field(
        default_factory=list,
    )

    # ─── Stops / Route Legs ─────────────────────────────────────────────────

    stops: list[RideStopResponse] = Field(
        default_factory=list,
    )

    route_legs: list[RideRouteLegResponse] = Field(
        default_factory=list,
    )

    # ─── Policies ──────────────────────────────────────────────────────────

    is_women_only: bool
    democratic_consent: bool

    flexible_pickup: bool
    allow_luggage: bool
    allow_pets: bool
    allow_music: bool
    is_ac: bool

    additional_notes: str

    terms_accepted: bool

    # ─── Lifecycle ─────────────────────────────────────────────────────────

    status: str

    # ─── Booking / Editability ─────────────────────────────────────────────

    has_booking: bool = False

    can_edit: bool = False

    edit_block_reason: Optional[str] = None

    # ─── Timestamps ─────────────────────────────────────────────────────────

    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(
        from_attributes=True,
    )


# ═════════════════════════════════════════════════════════════════════════════
# RESPONSE: CANCEL ACTION
# ═════════════════════════════════════════════════════════════════════════════


class RideCancelResponse(BaseModel):
    ride_id: int

    status: str

    message: str


# ═════════════════════════════════════════════════════════════════════════════
# COMMUNITY RIDE — SHARED NESTED SCHEMAS
# ═════════════════════════════════════════════════════════════════════════════


class CommunityRideHostResponse(BaseModel):
    """
    Public host information shown on community rides.

    Registration / private authentication information is never exposed.
    """

    name: str = Field(
        default="Unknown Host",
        min_length=1,
        max_length=100,
    )

    avatar_url: str | None = Field(
        default=None,
        max_length=500,
    )

    rating: float = Field(
        default=0.0,
        ge=0.0,
        le=5.0,
    )

    behavioural_rating: float = Field(
        default=0.0,
        ge=0.0,
        le=5.0,
    )

    completed_rides_count: int = Field(
        default=0,
        ge=0,
    )

    model_config = ConfigDict(
        from_attributes=True,
    )


class CommunityRideStopResponse(BaseModel):
    """
    Stop belonging to a community ride.

    Stops are included in the card because the frontend can use them
    for the future route/stop presentation.
    """

    id: int = Field(
        ...,
        gt=0,
    )

    stop_order: int = Field(
        ...,
        ge=1,
    )

    stop_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    latitude: float = Field(
        ...,
        ge=-90.0,
        le=90.0,
    )

    longitude: float = Field(
        ...,
        ge=-180.0,
        le=180.0,
    )

    model_config = ConfigDict(
        from_attributes=True,
    )


class CommunityRideVehicleResponse(BaseModel):
    """
    Public vehicle information.

    Registration number is intentionally excluded.

    Registration number will only be exposed later through the
    booking/live-ride flow.
    """

    category: str = Field(
        ...,
        min_length=1,
        max_length=50,
    )

    subtype: str = Field(
        ...,
        min_length=1,
        max_length=50,
    )

    model: str = Field(
        ...,
        min_length=1,
        max_length=100,
    )

    color: str | None = Field(
        default=None,
        max_length=50,
    )

    seating_capacity: int = Field(
        ...,
        ge=1,
        le=100,
    )

    model_config = ConfigDict(
        from_attributes=True,
    )


class CommunityRidePreferencesResponse(BaseModel):
    """
    Ride preferences/features visible to passengers.
    """

    women_only: bool = False

    ac: bool = False

    allow_luggage: bool = False

    allow_pets: bool = False

    allow_music: bool = False

    flexible_pickup: bool = False


class CommunityRideOriginDestinationResponse(BaseModel):
    """
    Coordinate information used by the detailed ride page.
    """

    name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    latitude: float = Field(
        ...,
        ge=-90.0,
        le=90.0,
    )

    longitude: float = Field(
        ...,
        ge=-180.0,
        le=180.0,
    )


class CommunityRideRouteLegResponse(BaseModel):
    """
    One confirmed route leg used by the detailed ride page.
    """

    id: int = Field(
        ...,
        gt=0,
    )

    leg_order: int = Field(
        ...,
        ge=1,
    )

    start_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    start_lat: float = Field(
        ...,
        ge=-90.0,
        le=90.0,
    )

    start_lng: float = Field(
        ...,
        ge=-180.0,
        le=180.0,
    )

    end_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    end_lat: float = Field(
        ...,
        ge=-90.0,
        le=90.0,
    )

    end_lng: float = Field(
        ...,
        ge=-180.0,
        le=180.0,
    )

    distance_meters: float = Field(
        ...,
        ge=0.0,
    )

    duration_seconds: float = Field(
        ...,
        ge=0.0,
    )

    geometry: list[GeoPoint] = Field(
        default_factory=list,
    )

    model_config = ConfigDict(
        from_attributes=True,
    )


# ═════════════════════════════════════════════════════════════════════════════
# COMMUNITY RIDE CARD RESPONSE
# ═════════════════════════════════════════════════════════════════════════════


class CommunityRideCardResponse(BaseModel):
    """
    Lightweight response used by the Community Ride Card.

    This response intentionally contains only information required
    for ride discovery on the homepage.

    Registration number is NOT included.
    """

    # ─── Ride Identity ──────────────────────────────────────────────────────

    ride_id: int = Field(
        ...,
        gt=0,
    )

    # ─── Host ───────────────────────────────────────────────────────────────

    host: CommunityRideHostResponse = Field(
        default_factory=CommunityRideHostResponse,
    )

    # ─── Route ──────────────────────────────────────────────────────────────

    origin_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    destination_name: str = Field(
        ...,
        min_length=1,
        max_length=200,
    )

    stops: list[CommunityRideStopResponse] = Field(
        default_factory=list,
    )

    # ─── Schedule ───────────────────────────────────────────────────────────

    departure_time: datetime

    ride_now: bool = False

    # ─── Fare / Seats ───────────────────────────────────────────────────────

    fare_per_seat: Decimal = Field(
        ...,
        ge=Decimal("0.00"),
        decimal_places=2,
        max_digits=10,
    )

    available_seats: int = Field(
        ...,
        ge=0,
        le=100,
    )

    # ─── Route Matching ─────────────────────────────────────────────────────

    route_match_percentage: float = Field(
        default=0.0,
        ge=0.0,
        le=100.0,
    )

    # ─── Vehicle ────────────────────────────────────────────────────────────

    vehicle: CommunityRideVehicleResponse

    # ─── Ride Features ──────────────────────────────────────────────────────

    is_women_only: bool = False

    is_ac: bool = False

    allow_luggage: bool = False

    allow_pets: bool = False

    allow_music: bool = False

    flexible_pickup: bool = False

    # ─── Lifecycle ─────────────────────────────────────────────────────────

    status: str = Field(
        default="scheduled",
        min_length=1,
        max_length=30,
    )


# ═════════════════════════════════════════════════════════════════════════════
# COMMUNITY RIDE DETAIL RESPONSE
# ═════════════════════════════════════════════════════════════════════════════


class CommunityRideDetailResponse(BaseModel):
    """
    Complete response used by the Ride Details page.

    Registration number is intentionally excluded.

    Registration number will be exposed only after the booking flow
    reaches the appropriate live-ride stage.
    """

    # ─── Ride Identity ──────────────────────────────────────────────────────

    ride_id: int = Field(
        ...,
        gt=0,
    )

    # ─── Host ───────────────────────────────────────────────────────────────

    host: CommunityRideHostResponse = Field(
        default_factory=CommunityRideHostResponse,
    )

    # ─── Origin / Destination ───────────────────────────────────────────────

    origin: CommunityRideOriginDestinationResponse

    destination: CommunityRideOriginDestinationResponse

    # ─── Stops ──────────────────────────────────────────────────────────────

    stops: list[CommunityRideStopResponse] = Field(
        default_factory=list,
    )

    # ─── Schedule ───────────────────────────────────────────────────────────

    departure_time: datetime

    ride_now: bool = False

    # ─── Seats / Fare ───────────────────────────────────────────────────────

    fare_per_seat: Decimal = Field(
        ...,
        ge=Decimal("0.00"),
        decimal_places=2,
        max_digits=10,
    )

    available_seats: int = Field(
        ...,
        ge=0,
        le=100,
    )

    # ─── Route Information ─────────────────────────────────────────────────

    route_distance_meters: float = Field(
        ...,
        ge=0.0,
    )

    route_duration_seconds: float = Field(
        ...,
        ge=0.0,
    )

    route_match_percentage: float = Field(
        default=0.0,
        ge=0.0,
        le=100.0,
    )

    route_geometry: list[GeoPoint] = Field(
        default_factory=list,
    )

    route_legs: list[CommunityRideRouteLegResponse] = Field(
        default_factory=list,
    )

    # ─── Vehicle ────────────────────────────────────────────────────────────

    vehicle: CommunityRideVehicleResponse

    # ─── Preferences / Features ─────────────────────────────────────────────

    preferences: CommunityRidePreferencesResponse = Field(
        default_factory=CommunityRidePreferencesResponse,
    )

    # ─── Additional Information ─────────────────────────────────────────────

    additional_notes: str = Field(
        default="",
        max_length=2000,
    )

    # ─── Lifecycle ─────────────────────────────────────────────────────────

    status: str = Field(
        default="scheduled",
        min_length=1,
        max_length=30,
    )

    # ─── Timestamps ─────────────────────────────────────────────────────────

    created_at: datetime

    updated_at: datetime