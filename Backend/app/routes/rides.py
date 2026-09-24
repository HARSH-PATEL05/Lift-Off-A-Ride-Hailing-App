from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db

from app.db.models.aadhar_document import Aadhaar
from app.db.models.driving_licence import DrivingLicence
from app.db.models.host_stat import HostStat
from app.db.models.ride import Ride
from app.db.models.ride_route_leg import RideRouteLeg
from app.db.models.ride_stop import RideStop
from app.db.models.user import User
from app.db.models.user_vehicle import UserVehicle
from app.db.models.vehicle import Vehicle
from app.db.models.vehicle_rc import VehicleRC

from app.db.schemas.ride import (
    RideCancelResponse,
    RideCreateRequest,
    RideUpdateRequest,
    RideResponse,
    RideRouteLegResponse,
    RideStopResponse,
)

from app.dependencies.auth import get_current_user

from app.services.geo_service import (
    api_points_from_geometry,
    line_from_api_points,
)

from app.services.fare_service import (
    FareInput,
    calculate_fare_per_seat,
)


router = APIRouter(
    prefix="/rides",
    tags=["Rides"],
)


# ─── Ride lifecycle ───────────────────────────────────────────────────────────
#
# A ride has three time-based non-cancelled states:
#
#   scheduled -> more than 5 minutes before departure
#   active    -> from 5 minutes before departure until the route ends
#   completed -> after departure + confirmed route duration
#
# Cancelled rides remain cancelled and are never changed by the lifecycle
# synchronizer.
RIDE_ACTIVE_WINDOW = timedelta(minutes=5)


def _as_utc(value: datetime) -> datetime:
    """Return a timezone-aware UTC datetime."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _get_ride_lifecycle_status(
    departure_time: datetime,
    route_duration_seconds: float,
    ride_now: bool,
    now: datetime | None = None,
) -> str:
    """
    Derive the current lifecycle status from the stored ride timing.

    Ride Now rides use their server-side departure_time, so they enter
    active immediately. Scheduled rides enter active exactly 5 minutes
    before departure.

    Completion is based on the confirmed route duration rather than
    departure time alone.
    """
    current_time = _as_utc(now or datetime.now(timezone.utc))
    departure = _as_utc(departure_time)

    try:
        duration_seconds = max(float(route_duration_seconds), 0.0)
    except (TypeError, ValueError):
        duration_seconds = 0.0

    completion_time = departure + timedelta(seconds=duration_seconds)
    active_start = departure if ride_now else departure - RIDE_ACTIVE_WINDOW

    if current_time >= completion_time:
        return "completed"

    if current_time >= active_start:
        return "active"

    return "scheduled"


def _sync_ride_status(
    ride: Ride,
    now: datetime | None = None,
) -> bool:
    """
    Synchronize a ride's persisted status with its current lifecycle.

    Returns True when the database value was changed.
    Cancelled rides are intentionally left untouched.
    """
    if ride.status == "cancelled":
        return False

    next_status = _get_ride_lifecycle_status(
        departure_time=ride.departure_time,
        route_duration_seconds=ride.route_duration_seconds,
        ride_now=ride.ride_now,
        now=now,
    )

    if ride.status != next_status:
        ride.status = next_status
        return True

    return False


def _ride_has_booking(ride: Ride) -> bool:
    """
    Booking compatibility hook.

    Booking/matching is not implemented yet, so the current system
    deliberately reports False for every ride. When booking is added,
    replace this implementation with the real booking lookup without
    changing the edit API contract.
    """

    return False


def _get_editability(ride: Ride) -> tuple[bool, str | None]:
    """
    Return the backend-owned edit permission for a published ride.

    Current rule:
      - ride must be active
      - no booking must exist
      - departure must be more than 10 minutes away

    The booking condition is currently always False because booking has
    not been implemented yet.
    """

    if ride.status not in {"scheduled", "active"}:
        return False, f"Ride is already '{ride.status}' and cannot be edited."

    if _ride_has_booking(ride):
        return False, "Ride cannot be edited after a booking has been made."

    departure_time = ride.departure_time
    if departure_time.tzinfo is None:
        departure_time = departure_time.replace(tzinfo=timezone.utc)
    else:
        departure_time = departure_time.astimezone(timezone.utc)

    now = datetime.now(timezone.utc)
    remaining = departure_time - now

    if remaining <= timedelta(0):
        return False, "Ride departure time has already passed."

    if remaining <= timedelta(minutes=10):
        return False, "Ride cannot be edited within 10 minutes of departure."

    return True, None


# ─── Helpers ─────────────────────────────────────────────────────────────────


def _build_response(
    ride: Ride,
    host: User | None,
) -> RideResponse:
    """
    Map ORM Ride + related objects into RideResponse.

    PostGIS geometry is converted back into the API's normal
    latitude/longitude representation so Flutter does not need
    to know anything about PostGIS.
    """

    stops = [
        RideStopResponse(
            id=stop.id,
            ride_id=stop.ride_id,
            stop_order=stop.stop_order,
            stop_name=stop.stop_name,
            stop_lat=stop.stop_lat,
            stop_lng=stop.stop_lng,
        )
        for stop in ride.stops
    ]

    route_legs = [
        RideRouteLegResponse(
            id=leg.id,
            ride_id=leg.ride_id,
            leg_order=leg.leg_order,
            start_name=leg.start_name,
            start_lat=leg.start_lat,
            start_lng=leg.start_lng,
            end_name=leg.end_name,
            end_lat=leg.end_lat,
            end_lng=leg.end_lng,
            distance_meters=leg.distance_meters,
            duration_seconds=leg.duration_seconds,
            geometry=api_points_from_geometry(
                leg.geometry
            ),
        )
        for leg in ride.route_legs
    ]

    return RideResponse(
        ride_id=ride.id,

        host_id=(
            host.supabase_user_id
            if host
            else str(ride.host_user_id)
        ),

        host_name=host.full_name if host else None,
        host_avatar=host.avatar_url if host else None,

        origin_name=ride.origin_name,
        origin_lat=ride.origin_lat,
        origin_lng=ride.origin_lng,

        destination_name=ride.destination_name,
        destination_lat=ride.destination_lat,
        destination_lng=ride.destination_lng,

        departure_time=ride.departure_time,
        ride_now=ride.ride_now,

        available_seats=ride.available_seats,

        vehicle_id=ride.vehicle_id,

        vehicle_model=(
            ride.vehicle.vehicle_model
            if ride.vehicle is not None
            else None
        ),
        vehicle_registration_number=(
            ride.vehicle.registration_number
            if ride.vehicle is not None
            else None
        ),
        vehicle_category=(
            ride.vehicle.vehicle_category
            if ride.vehicle is not None
            else None
        ),
        vehicle_subtype=(
            ride.vehicle.vehicle_subtype
            if ride.vehicle is not None
            else None
        ),
        vehicle_type_specified=(
            ride.vehicle.vehicle_type_specified
            if ride.vehicle is not None
            else None
        ),
        seating_capacity=(
            ride.vehicle.seating_capacity
            if ride.vehicle is not None
            else None
        ),

        fare_per_seat=Decimal(
            str(ride.fare_per_seat)
        ),

        route_distance_meters=ride.route_distance_meters,
        route_duration_seconds=ride.route_duration_seconds,

        route_geometry=api_points_from_geometry(
            ride.route_geometry
        ),

        stops=stops,
        route_legs=route_legs,

        is_women_only=ride.is_women_only,
        democratic_consent=ride.democratic_consent,

        flexible_pickup=ride.flexible_pickup,
        allow_luggage=ride.allow_luggage,
        allow_pets=ride.allow_pets,
        allow_music=ride.allow_music,
        is_ac=ride.is_ac,

        additional_notes=ride.additional_notes,

        terms_accepted=ride.terms_accepted,

        status=ride.status,

        has_booking=_ride_has_booking(ride),
        can_edit=_get_editability(ride)[0],
        edit_block_reason=_get_editability(ride)[1],

        created_at=ride.created_at,
        updated_at=ride.updated_at,
    )


def _get_current_db_user(
    current_user,
    db: Session,
) -> User:
    """
    Resolve the authenticated Supabase user to the local users row.
    """

    db_user = (
        db.query(User)
        .filter(
            User.supabase_user_id == current_user.id
        )
        .first()
    )

    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                "User profile not found. "
                "Please sync your account first."
            ),
        )

    return db_user


def _validate_verified_host(
    db_user: User,
    db: Session,
) -> None:
    """
    Verify the host's required identity documents.

    Current LiftOff ride-publishing rule:

        Aadhaar + Driving Licence + Vehicle RC

    Vehicle RC is validated separately against the selected
    vehicle by _get_verified_host_vehicle().
    """

    aadhaar = (
        db.query(Aadhaar)
        .filter(
            Aadhaar.user_id == db_user.id
        )
        .first()
    )

    dl = (
        db.query(DrivingLicence)
        .filter(
            DrivingLicence.user_id == db_user.id
        )
        .first()
    )

    is_aadhaar_ok = (
        aadhaar is not None
        and aadhaar.aadhaar_verified
    )

    is_dl_ok = (
        dl is not None
        and dl.dl_verified
    )

    if not is_aadhaar_ok or not is_dl_ok:
        unverified_docs = []

        if not is_aadhaar_ok:
            unverified_docs.append("Aadhaar")

        if not is_dl_ok:
            unverified_docs.append("Driving Licence")

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Required identity documents must be verified "
                "before offering rides. Pending: "
                f"{', '.join(unverified_docs)}."
            ),
        )


def _get_verified_host_vehicle(
    db_user: User,
    vehicle_id: int,
    db: Session,
) -> Vehicle:
    """
    Resolve and validate the vehicle selected in Module 3.

    Conditions:
      1. Vehicle exists.
      2. Vehicle belongs to this host through UserVehicle.
      3. UserVehicle association is active.
      4. Vehicle has a verified RC.
    """

    user_vehicle = (
        db.query(UserVehicle)
        .filter(
            UserVehicle.user_id == db_user.id,
            UserVehicle.vehicle_id == vehicle_id,
            UserVehicle.is_active.is_(True),
        )
        .first()
    )

    if not user_vehicle:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "The selected vehicle does not belong to your "
                "active verified vehicles."
            ),
        )

    vehicle = (
        db.query(Vehicle)
        .filter(
            Vehicle.id == vehicle_id
        )
        .first()
    )

    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Selected vehicle was not found.",
        )

    vehicle_rc = (
        db.query(VehicleRC)
        .filter(
            VehicleRC.vehicle_id == vehicle.id,
            VehicleRC.rc_verified.is_(True),
        )
        .first()
    )

    if not vehicle_rc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "The selected vehicle does not have a verified "
                "Vehicle RC."
            ),
        )

    return vehicle


def _validate_route_payload(
    payload: RideCreateRequest | RideUpdateRequest,
) -> None:
    """
    Validate consistency of the route snapshot supplied by
    Modules 1 and 2.
    """

    if len(payload.route_geometry) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Selected route must contain at least "
                "two geometry points."
            ),
        )

    if not payload.route_legs:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one route leg is required.",
        )

    expected_leg_order = 1

    for leg in payload.route_legs:

        if leg.leg_order != expected_leg_order:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Route legs must have sequential "
                    "leg_order values."
                ),
            )

        if len(leg.geometry) < 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Route leg {leg.leg_order} must contain "
                    "at least two geometry points."
                ),
            )

        expected_leg_order += 1

    expected_stop_order = 1

    for stop in payload.stops:

        if stop.stop_order != expected_stop_order:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Stops must have sequential "
                    "stop_order values."
                ),
            )

        expected_stop_order += 1


def _calculate_ride_fare(
    payload: RideCreateRequest | RideUpdateRequest,
    vehicle: Vehicle,
    departure_time: datetime,
) -> Decimal:
    """
    Calculate fare entirely on the backend.

    All finalized FareInput fields are supplied here.

    At ride publication:
      - passenger_count = 0
      - requested_seats = 0

    These booking-context values are populated later by the
    passenger booking/matching workflow.
    """

    fare_input = FareInput(
        # ─────────────────────────────────────────
        # Route
        # ─────────────────────────────────────────

        distance_meters=payload.route_distance_meters,
        duration_seconds=payload.route_duration_seconds,

        number_of_stops=len(payload.stops),
        number_of_legs=len(payload.route_legs),

        # ─────────────────────────────────────────
        # Timing
        # ─────────────────────────────────────────

        departure_time=departure_time,
        ride_now=payload.ride_now,

        # ─────────────────────────────────────────
        # Vehicle
        # ─────────────────────────────────────────

        vehicle_category=vehicle.vehicle_category,
        vehicle_subtype=vehicle.vehicle_subtype,
        vehicle_type_specified=vehicle.vehicle_type_specified,

        seating_capacity=vehicle.seating_capacity,
        available_seats=payload.available_seats,

        # ─────────────────────────────────────────
        # Ride Preferences
        # ─────────────────────────────────────────

        is_ac=payload.is_ac,
        flexible_pickup=payload.flexible_pickup,
        allow_luggage=payload.allow_luggage,
        allow_pets=payload.allow_pets,
        allow_music=payload.allow_music,
        is_women_only=payload.is_women_only,

        # ─────────────────────────────────────────
        # Passenger / Booking
        # ─────────────────────────────────────────
        #
        # A newly published ride has no passengers
        # and no passenger seat request yet.

        passenger_count=0,
        requested_seats=0,

        # ─────────────────────────────────────────
        # Booking Context
        # ─────────────────────────────────────────

        booking_time=None,
    )

    try:
        fare = calculate_fare_per_seat(
            fare_input
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Fare calculation failed: {exc}",
        ) from exc

    if fare < Decimal("0"):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=(
                "Backend fare calculation returned "
                "an invalid value."
            ),
        )

    return fare.quantize(
        Decimal("0.01")
    )


# ─── POST /rides — Publish a commute route ──────────────────────────────────


@router.post(
    "",
    response_model=RideResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Publish a commute ride (host only)",
)
def create_ride(
    payload: RideCreateRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RideResponse:
    """
    Publish a confirmed commute route.

    Module 1:
      - source
      - stops
      - destination
      - route
      - departure time

    Module 2:
      - final route selection

    Module 3:
      - verified vehicle
      - passenger seat count
      - ride preferences
      - terms acceptance

    Backend:
      - validates host
      - validates vehicle
      - validates seats
      - validates schedule
      - converts route geometry to PostGIS
      - calculates fare
      - stores the complete ride snapshot
    """

    # ── Resolve local user ───────────────────────────────────────

    db_user = _get_current_db_user(
        current_user,
        db,
    )

    # ── Identity verification ───────────────────────────────────

    _validate_verified_host(
        db_user,
        db,
    )

    # ── Terms ────────────────────────────────────────────────────

    if not payload.terms_accepted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must accept the ride publishing terms.",
        )

    # ── Schedule validation ──────────────────────────────────────

    now = datetime.now(timezone.utc)

    departure_time = payload.departure_time

    if departure_time.tzinfo is None:
        departure_time = departure_time.replace(
            tzinfo=timezone.utc
        )
    else:
        departure_time = departure_time.astimezone(
            timezone.utc
        )

    if payload.ride_now:

        # Ride Now intentionally uses server time.
        departure_time = now

    else:

        # Preserve the exact scheduled departure selected
        # in Module 1.

        if departure_time <= now:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Scheduled departure time must be "
                    "in the future."
                ),
            )

    # ── Vehicle validation ──────────────────────────────────────

    vehicle = _get_verified_host_vehicle(
        db_user,
        payload.vehicle_id,
        db,
    )

    # ── Seat capacity validation ────────────────────────────────
    #
    # Maximum LiftOff passenger seats:
    #
    #     seating_capacity - 1
    #
    # One seat is reserved for the host.

    max_available_seats = (
        vehicle.seating_capacity - 1
    )

    if max_available_seats < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "This vehicle does not have enough seating "
                "capacity to offer a passenger seat."
            ),
        )

    if payload.available_seats > max_available_seats:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"This vehicle allows a maximum of "
                f"{max_available_seats} passenger seat(s) "
                "on LiftOff."
            ),
        )

    # ── Route validation ─────────────────────────────────────────

    _validate_route_payload(
        payload
    )

    # ── Convert complete route to PostGIS ────────────────────────

    try:
        route_geometry = line_from_api_points(
            payload.route_geometry
        )

        route_leg_geometries = {
            leg.leg_order: line_from_api_points(
                leg.geometry
            )
            for leg in payload.route_legs
        }

    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid route geometry: {exc}",
        ) from exc

    # ── Backend fare calculation ─────────────────────────────────
    #
    # Flutter never supplies fare.

    fare_per_seat = _calculate_ride_fare(
        payload,
        vehicle,
        departure_time,
    )

    # ── Create Ride ──────────────────────────────────────────────

    ride = Ride(
        host_user_id=db_user.id,

        origin_name=payload.origin_name.strip(),
        origin_lat=payload.origin_lat,
        origin_lng=payload.origin_lng,

        destination_name=payload.destination_name.strip(),
        destination_lat=payload.destination_lat,
        destination_lng=payload.destination_lng,

        # Exact validated UTC departure instant.
        departure_time=departure_time,
        ride_now=payload.ride_now,

        available_seats=payload.available_seats,

        vehicle_id=vehicle.id,

        # Backend-generated fare.
        fare_per_seat=float(fare_per_seat),

        route_distance_meters=payload.route_distance_meters,
        route_duration_seconds=payload.route_duration_seconds,

        # PostGIS LINESTRING.
        route_geometry=route_geometry,

        is_women_only=payload.is_women_only,
        democratic_consent=payload.democratic_consent,

        flexible_pickup=payload.flexible_pickup,
        allow_luggage=payload.allow_luggage,
        allow_pets=payload.allow_pets,
        allow_music=payload.allow_music,
        is_ac=payload.is_ac,

        additional_notes=payload.additional_notes.strip(),

        terms_accepted=payload.terms_accepted,

        # Persist the lifecycle status immediately. Scheduled rides stay
        # scheduled until the 5-minute active window begins.
        status=_get_ride_lifecycle_status(
            departure_time=departure_time,
            route_duration_seconds=payload.route_duration_seconds,
            ride_now=payload.ride_now,
            now=now,
        ),
    )

    db.add(ride)

    # Flush so ride.id becomes available for child rows.
    db.flush()

    # ── Create Ride Stops ────────────────────────────────────────

    for stop_data in payload.stops:

        stop = RideStop(
            ride_id=ride.id,
            stop_order=stop_data.stop_order,
            stop_name=stop_data.stop_name.strip(),
            stop_lat=stop_data.stop_lat,
            stop_lng=stop_data.stop_lng,
        )

        db.add(stop)

    # ── Create Route Legs ────────────────────────────────────────

    for leg_data in payload.route_legs:

        route_leg = RideRouteLeg(
            ride_id=ride.id,
            leg_order=leg_data.leg_order,

            start_name=leg_data.start_name.strip(),
            start_lat=leg_data.start_lat,
            start_lng=leg_data.start_lng,

            end_name=leg_data.end_name.strip(),
            end_lat=leg_data.end_lat,
            end_lng=leg_data.end_lng,

            distance_meters=leg_data.distance_meters,
            duration_seconds=leg_data.duration_seconds,

            geometry=route_leg_geometries[
                leg_data.leg_order
            ],
        )

        db.add(route_leg)

    # ── Update Host Stats ────────────────────────────────────────

    host_stat = (
        db.query(HostStat)
        .filter(
            HostStat.user_id == db_user.id
        )
        .first()
    )

    if host_stat is None:
        host_stat = HostStat(
            user_id=db_user.id,
        )
        db.add(host_stat)

    host_stat.shared_commutes_count += 1
    host_stat.co2_saved_kg += 4.2

    # Fare/payment is handled by the payment workflow.
    # Do not modify fuel_recovered_inr here.

    # ── Commit entire transaction ────────────────────────────────

    try:
        db.commit()

    except Exception:
        db.rollback()
        raise

    db.refresh(ride)

    return _build_response(
        ride,
        db_user,
    )


# ─── GET /rides — Browse all active rides ────────────────────────────────────


@router.get(
    "",
    response_model=List[RideResponse],
    summary="List all active rides",
)
def list_rides(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> List[RideResponse]:
    """
    Returns rides that are currently available to the matching/search flow.

    Scheduled rides are included because passengers may need to discover
    them before the 5-minute active window. Completed and cancelled rides
    are excluded.
    """

    rides = (
        db.query(Ride)
        .filter(
            Ride.status.in_(["scheduled", "active"])
        )
        .order_by(
            Ride.departure_time.asc()
        )
        .all()
    )

    now = datetime.now(timezone.utc)
    changed = False

    for ride in rides:
        if _sync_ride_status(ride, now):
            changed = True

    # A ride can cross from scheduled/active to completed while this
    # request is being processed, so remove anything no longer publishable.
    rides = [
        ride
        for ride in rides
        if ride.status in {"scheduled", "active"}
    ]

    if changed:
        db.commit()

    result = []

    for ride in rides:

        host = (
            db.query(User)
            .filter(
                User.id == ride.host_user_id
            )
            .first()
        )

        result.append(
            _build_response(
                ride,
                host,
            )
        )

    return result


# ─── GET /rides/my — Rides posted by current host ────────────────────────────


@router.get(
    "/my",
    response_model=List[RideResponse],
    summary="List rides posted by current user",
)
def list_my_rides(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> List[RideResponse]:
    """
    Returns all rides posted by the current host.
    """

    db_user = _get_current_db_user(
        current_user,
        db,
    )

    rides = (
        db.query(Ride)
        .filter(
            Ride.host_user_id == db_user.id
        )
        .order_by(
            Ride.created_at.desc()
        )
        .all()
    )

    now = datetime.now(timezone.utc)
    changed = False

    for ride in rides:
        if _sync_ride_status(ride, now):
            changed = True

    if changed:
        db.commit()

    return [
        _build_response(
            ride,
            db_user,
        )
        for ride in rides
    ]


# ─── PATCH /rides/{ride_id} — Edit a published ride ─────────────────────────


@router.patch(
    "/{ride_id}",
    response_model=RideResponse,
    summary="Edit a published ride (host only)",
)
def update_ride(
    ride_id: int,
    payload: RideUpdateRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RideResponse:
    """
    Edit a published ride.

    Current booking compatibility rule:
        Booking is not implemented yet, so every ride currently has
        has_booking=False. The booking check is kept behind
        _ride_has_booking() so the real booking workflow can replace it
        later without changing this endpoint.

    Edit is allowed only when:
        1. The authenticated user owns the ride.
        2. The ride is scheduled/active and still more than 10 minutes away.
        3. No booking exists.

    The client sends a complete ride snapshot. Route geometry, stops and
    route legs are replaced together so they cannot become inconsistent.
    Fare is always recalculated by the backend.
    """

    db_user = _get_current_db_user(
        current_user,
        db,
    )

    ride = (
        db.query(Ride)
        .filter(Ride.id == ride_id)
        .first()
    )

    if not ride:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Ride {ride_id} not found.",
        )

    if ride.host_user_id != db_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only edit your own rides.",
        )

    if _sync_ride_status(ride):
        db.commit()
        db.refresh(ride)

    can_edit, reason = _get_editability(ride)
    if not can_edit:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=reason or "This ride cannot be edited.",
        )

    # ── Schedule validation ──────────────────────────────────────

    now = datetime.now(timezone.utc)
    departure_time = payload.departure_time

    if departure_time.tzinfo is None:
        departure_time = departure_time.replace(
            tzinfo=timezone.utc
        )
    else:
        departure_time = departure_time.astimezone(
            timezone.utc
        )

    if payload.ride_now:
        departure_time = now
    elif departure_time <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Scheduled departure time must be in the future.",
        )

    # ── Vehicle validation ──────────────────────────────────────

    vehicle = _get_verified_host_vehicle(
        db_user,
        payload.vehicle_id,
        db,
    )

    max_available_seats = vehicle.seating_capacity - 1

    if max_available_seats < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "This vehicle does not have enough seating capacity "
                "to offer a passenger seat."
            ),
        )

    if payload.available_seats > max_available_seats:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"This vehicle allows a maximum of "
                f"{max_available_seats} passenger seat(s) on LiftOff."
            ),
        )

    # ── Route validation ─────────────────────────────────────────

    _validate_route_payload(payload)

    try:
        route_geometry = line_from_api_points(
            payload.route_geometry
        )

        route_leg_geometries = {
            leg.leg_order: line_from_api_points(
                leg.geometry
            )
            for leg in payload.route_legs
        }
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid route geometry: {exc}",
        ) from exc

    # ── Backend fare recalculation ───────────────────────────────

    fare_per_seat = _calculate_ride_fare(
        payload,
        vehicle,
        departure_time,
    )

    # ── Update parent ride ───────────────────────────────────────

    ride.origin_name = payload.origin_name.strip()
    ride.origin_lat = payload.origin_lat
    ride.origin_lng = payload.origin_lng

    ride.destination_name = payload.destination_name.strip()
    ride.destination_lat = payload.destination_lat
    ride.destination_lng = payload.destination_lng

    ride.departure_time = departure_time
    ride.ride_now = payload.ride_now
    ride.available_seats = payload.available_seats
    ride.vehicle_id = vehicle.id

    ride.fare_per_seat = float(fare_per_seat)

    ride.route_distance_meters = payload.route_distance_meters
    ride.route_duration_seconds = payload.route_duration_seconds
    ride.route_geometry = route_geometry

    ride.is_women_only = payload.is_women_only
    ride.democratic_consent = payload.democratic_consent
    ride.flexible_pickup = payload.flexible_pickup
    ride.allow_luggage = payload.allow_luggage
    ride.allow_pets = payload.allow_pets
    ride.allow_music = payload.allow_music
    ride.is_ac = payload.is_ac
    ride.additional_notes = payload.additional_notes.strip()

    # Recalculate lifecycle because both departure time and route duration
    # may have changed during an edit.
    ride.status = _get_ride_lifecycle_status(
        departure_time=departure_time,
        route_duration_seconds=payload.route_duration_seconds,
        ride_now=payload.ride_now,
        now=now,
    )

    # ── Replace route children as one synchronized snapshot ──────

    db.query(RideStop).filter(
        RideStop.ride_id == ride.id
    ).delete(synchronize_session=False)

    db.query(RideRouteLeg).filter(
        RideRouteLeg.ride_id == ride.id
    ).delete(synchronize_session=False)

    for stop_data in payload.stops:
        db.add(
            RideStop(
                ride_id=ride.id,
                stop_order=stop_data.stop_order,
                stop_name=stop_data.stop_name.strip(),
                stop_lat=stop_data.stop_lat,
                stop_lng=stop_data.stop_lng,
            )
        )

    for leg_data in payload.route_legs:
        db.add(
            RideRouteLeg(
                ride_id=ride.id,
                leg_order=leg_data.leg_order,
                start_name=leg_data.start_name.strip(),
                start_lat=leg_data.start_lat,
                start_lng=leg_data.start_lng,
                end_name=leg_data.end_name.strip(),
                end_lat=leg_data.end_lat,
                end_lng=leg_data.end_lng,
                distance_meters=leg_data.distance_meters,
                duration_seconds=leg_data.duration_seconds,
                geometry=route_leg_geometries[leg_data.leg_order],
            )
        )

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise

    db.refresh(ride)

    return _build_response(
        ride,
        db_user,
    )


# ─── PATCH /rides/{ride_id}/cancel ───────────────────────────────────────────


@router.patch(
    "/{ride_id}/cancel",
    response_model=RideCancelResponse,
    summary="Cancel a ride (only by the host who posted it)",
)
def cancel_ride(
    ride_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RideCancelResponse:
    """
    Soft-cancel a ride.

    Only the host who created the ride can cancel it.
    """

    db_user = _get_current_db_user(
        current_user,
        db,
    )

    ride = (
        db.query(Ride)
        .filter(
            Ride.id == ride_id
        )
        .first()
    )

    if not ride:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Ride {ride_id} not found.",
        )

    if ride.host_user_id != db_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only cancel your own rides.",
        )

    # Refresh lifecycle first so the cancellation decision is based on
    # the current server time, not a stale persisted status.
    _sync_ride_status(ride)

    # Host cancellation is intentionally allowed ONLY for scheduled rides.
    # Active rides are not cancellable here; their future automatic
    # unoccurrence/expiry handling will be implemented separately.
    if ride.status != "scheduled":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Ride is '{ride.status}' and cannot be cancelled by the "
                "host. Only scheduled rides can be cancelled."
            ),
        )

    # Keep the same 10-minute safety window used by ride editing.
    departure_time = ride.departure_time
    if departure_time.tzinfo is None:
        departure_time = departure_time.replace(tzinfo=timezone.utc)
    else:
        departure_time = departure_time.astimezone(timezone.utc)

    remaining = departure_time - datetime.now(timezone.utc)

    if remaining <= timedelta(minutes=10):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Scheduled ride cannot be cancelled within 10 minutes "
                "of departure."
            ),
        )

    # Booking/matching compatibility hook.
    # Currently this returns False because booking is not implemented yet.
    if _ride_has_booking(ride):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Scheduled ride cannot be cancelled after a booking has been made.",
        )

    ride.status = "cancelled"

    db.commit()

    return RideCancelResponse(
        ride_id=ride.id,
        status="cancelled",
        message="Ride successfully cancelled.",
    )