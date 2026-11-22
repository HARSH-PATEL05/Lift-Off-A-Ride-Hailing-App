from datetime import datetime, timezone, timedelta
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db.database import get_db

from app.db.models.ride import Ride
from app.db.models.user import User
from app.db.models.vehicle import Vehicle
from app.db.models.host_stat import HostStat

from app.dependencies.auth import get_current_user

from app.db.schemas.ride import (
    CommunityRideCardResponse,
    CommunityRideDetailResponse,
    CommunityRideHostResponse,
    CommunityRideStopResponse,
    CommunityRideVehicleResponse,
    CommunityRidePreferencesResponse,
    CommunityRideOriginDestinationResponse,
    CommunityRideRouteLegResponse,
    GeoPoint,
)


router = APIRouter(
    prefix="/community-rides",
    tags=["Community Rides"],
)


# ═════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═════════════════════════════════════════════════════════════════════════════

DEFAULT_ROUTE_MATCH_THRESHOLD = 50.0


# ═════════════════════════════════════════════════════════════════════════════
# COMMON HELPERS
# ═════════════════════════════════════════════════════════════════════════════


def _as_utc(value: datetime) -> datetime:
    """
    Return a timezone-aware UTC datetime.
    """

    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)

    return value.astimezone(timezone.utc)


def _sync_ride_status(
    ride: Ride,
    now: datetime | None = None,
) -> bool:
    """
    Synchronize the ride lifecycle status.

    Returns:
        True  -> status changed
        False -> status unchanged
    """

    if ride.status == "cancelled":
        return False

    current_time = _as_utc(
        now or datetime.now(timezone.utc)
    )

    departure = _as_utc(
        ride.departure_time
    )

    try:
        duration_seconds = max(
            float(ride.route_duration_seconds),
            0.0,
        )
    except (TypeError, ValueError):
        duration_seconds = 0.0

    completion_time = (
        departure
        + timedelta(seconds=duration_seconds)
    )

    active_start = (
        departure
        if ride.ride_now
        else departure - timedelta(minutes=5)
    )

    if current_time >= completion_time:
        next_status = "completed"

    elif current_time >= active_start:
        next_status = "active"

    else:
        next_status = "scheduled"

    if ride.status != next_status:
        ride.status = next_status
        return True

    return False


def _get_host_stats(
    host: User,
) -> HostStat | None:
    """
    Return the host's aggregated statistics.

    HostStat is a one-to-one relationship with User.
    """

    return getattr(
        host,
        "host_stat",
        None,
    )


def _build_host_response(
    host: User,
) -> CommunityRideHostResponse:
    """
    Build the public host representation.

    Never exposes:
        - user id
        - email
        - phone number
        - Supabase id
        - vehicle registration
        - private verification data
    """

    stats = _get_host_stats(host)

    return CommunityRideHostResponse(
        name=(
            host.full_name
            if host.full_name
            else "Unknown Host"
        ),
        avatar_url=host.avatar_url,
        rating=(
            float(stats.rating)
            if stats is not None
            else 0.0
        ),
        behavioural_rating=(
            float(stats.behavioural_rating)
            if stats is not None
            else 0.0
        ),
        completed_rides_count=(
            int(stats.completed_rides_count)
            if stats is not None
            else 0
        ),
    )


def _build_vehicle_response(
    vehicle: Vehicle,
) -> CommunityRideVehicleResponse:
    """
    Build the public vehicle representation.

    IMPORTANT:
        registration_number is intentionally NOT returned.
    """

    return CommunityRideVehicleResponse(
        category=vehicle.vehicle_category,
        subtype=vehicle.vehicle_subtype,
        model=vehicle.vehicle_model,
        color=vehicle.vehicle_color,
        seating_capacity=vehicle.seating_capacity,
    )


def _build_stop_responses(
    ride: Ride,
) -> list[CommunityRideStopResponse]:
    """
    Convert RideStop ORM objects into public stop responses.
    """

    return [
        CommunityRideStopResponse(
            id=stop.id,
            stop_order=stop.stop_order,
            stop_name=stop.stop_name,
            latitude=stop.stop_lat,
            longitude=stop.stop_lng,
        )
        for stop in ride.stops
    ]


def _geometry_to_points(
    geometry,
) -> list[GeoPoint]:
    """
    Convert PostGIS geometry into API GeoPoint objects.

    The database stores:
        X = longitude
        Y = latitude

    The API exposes:
        latitude
        longitude
    """

    if geometry is None:
        return []

    try:
        from geoalchemy2.shape import to_shape

        shape = to_shape(geometry)

        if shape.is_empty:
            return []

        return [
            GeoPoint(
                latitude=float(lat),
                longitude=float(lng),
            )
            for lng, lat in shape.coords
        ]

    except Exception:
        return []


def _build_route_leg_responses(
    ride: Ride,
) -> list[CommunityRideRouteLegResponse]:
    """
    Convert RideRouteLeg ORM objects into public responses.
    """

    return [
        CommunityRideRouteLegResponse(
            id=leg.id,
            leg_order=leg.leg_order,

            start_name=leg.start_name,
            start_lat=leg.start_lat,
            start_lng=leg.start_lng,

            end_name=leg.end_name,
            end_lat=leg.end_lat,
            end_lng=leg.end_lng,

            distance_meters=leg.distance_meters,
            duration_seconds=leg.duration_seconds,

            geometry=_geometry_to_points(
                leg.geometry
            ),
        )
        for leg in ride.route_legs
    ]


def _build_origin_response(
    ride: Ride,
) -> CommunityRideOriginDestinationResponse:
    """
    Build the origin object used by the detail page.
    """

    return CommunityRideOriginDestinationResponse(
        name=ride.origin_name,
        latitude=ride.origin_lat,
        longitude=ride.origin_lng,
    )


def _build_destination_response(
    ride: Ride,
) -> CommunityRideOriginDestinationResponse:
    """
    Build the destination object used by the detail page.
    """

    return CommunityRideOriginDestinationResponse(
        name=ride.destination_name,
        latitude=ride.destination_lat,
        longitude=ride.destination_lng,
    )


def _build_preferences_response(
    ride: Ride,
) -> CommunityRidePreferencesResponse:
    """
    Build the grouped preference/feature response.
    """

    return CommunityRidePreferencesResponse(
        women_only=ride.is_women_only,
        ac=ride.is_ac,
        allow_luggage=ride.allow_luggage,
        allow_pets=ride.allow_pets,
        allow_music=ride.allow_music,
        flexible_pickup=ride.flexible_pickup,
    )


def _get_route_match_percentage(
    ride: Ride,
) -> float:
    """
    Temporary route-match boundary.

    The actual passenger-route vs host-route matching algorithm
    belongs in a dedicated route-matching service.

    Until that service is connected, a published community ride
    is represented as 0.0 rather than inventing a match percentage.

    The API structure is therefore ready for the future matcher.
    """

    return 0.0


def _build_card_response(
    ride: Ride,
) -> CommunityRideCardResponse:
    """
    Build the lightweight response used by the homepage.
    """

    return CommunityRideCardResponse(
        ride_id=ride.id,

        host=_build_host_response(
            ride.host
        ),

        origin_name=ride.origin_name,
        destination_name=ride.destination_name,

        stops=_build_stop_responses(
            ride
        ),

        departure_time=ride.departure_time,
        ride_now=ride.ride_now,

        fare_per_seat=Decimal(
            str(ride.fare_per_seat)
        ),

        available_seats=ride.available_seats,

        route_match_percentage=(
            _get_route_match_percentage(ride)
        ),

        vehicle=_build_vehicle_response(
            ride.vehicle
        ),

        is_women_only=ride.is_women_only,
        is_ac=ride.is_ac,
        allow_luggage=ride.allow_luggage,
        allow_pets=ride.allow_pets,
        allow_music=ride.allow_music,
        flexible_pickup=ride.flexible_pickup,

        status=ride.status,
    )


def _build_detail_response(
    ride: Ride,
) -> CommunityRideDetailResponse:
    """
    Build the complete response used by Ride Details page.
    """

    return CommunityRideDetailResponse(
        ride_id=ride.id,

        host=_build_host_response(
            ride.host
        ),

        origin=_build_origin_response(
            ride
        ),

        destination=_build_destination_response(
            ride
        ),

        stops=_build_stop_responses(
            ride
        ),

        departure_time=ride.departure_time,
        ride_now=ride.ride_now,

        fare_per_seat=Decimal(
            str(ride.fare_per_seat)
        ),

        available_seats=ride.available_seats,

        route_distance_meters=(
            ride.route_distance_meters
        ),

        route_duration_seconds=(
            ride.route_duration_seconds
        ),

        route_match_percentage=(
            _get_route_match_percentage(ride)
        ),

        route_geometry=_geometry_to_points(
            ride.route_geometry
        ),

        route_legs=_build_route_leg_responses(
            ride
        ),

        vehicle=_build_vehicle_response(
            ride.vehicle
        ),

        preferences=_build_preferences_response(
            ride
        ),

        additional_notes=(
            ride.additional_notes or ""
        ),

        status=ride.status,

        created_at=ride.created_at,
        updated_at=ride.updated_at,
    )


# ═════════════════════════════════════════════════════════════════════════════
# DATABASE QUERY
# ═════════════════════════════════════════════════════════════════════════════


def _community_ride_query():
    """
    Base query for community rides.

    Community rides are NOT restricted to the authenticated user's
    own rides.

    The authenticated user is only used to:
        - authorize access
        - optionally exclude their own rides
    """

    return (
        select(Ride)
        .options(
            selectinload(Ride.host)
            .selectinload(User.host_stat),

            selectinload(Ride.vehicle),

            selectinload(Ride.stops),

            selectinload(Ride.route_legs),
        )
    )


# ═════════════════════════════════════════════════════════════════════════════
# GET /community-rides
# ═════════════════════════════════════════════════════════════════════════════


@router.get(
    "",
    response_model=list[CommunityRideCardResponse],
    summary="Get community rides",
    description=(
        "Returns community rides published by hosts. "
        "The authenticated user can discover rides belonging to "
        "other accounts. Private host information and vehicle "
        "registration numbers are never exposed."
    ),
)
def get_community_rides(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),

    vehicle_category: Optional[str] = Query(
        default=None,
        description=(
            "Filter by vehicle category, for example "
            "2_WHEELER, 3_WHEELER or 4_WHEELER."
        ),
    ),

    vehicle_subtype: Optional[str] = Query(
        default=None,
    ),

    women_only: bool = Query(
        default=False,
    ),

    flexible_pickup: bool = Query(
        default=False,
    ),

    allow_luggage: bool = Query(
        default=False,
    ),

    allow_pets: bool = Query(
        default=False,
    ),

    allow_music: bool = Query(
        default=False,
    ),

    ac: bool = Query(
        default=False,
    ),

    min_seats: int = Query(
        default=1,
        ge=1,
        le=100,
    ),

    departure_from: Optional[datetime] = Query(
        default=None,
        description="Earliest acceptable departure time.",
    ),

    departure_to: Optional[datetime] = Query(
        default=None,
        description="Latest acceptable departure time.",
    ),

    exclude_own_rides: bool = Query(
        default=True,
        description="Exclude rides published by the current user.",
    ),

    limit: int = Query(
        default=20,
        ge=1,
        le=100,
    ),

    offset: int = Query(
        default=0,
        ge=0,
    ),
):
    """
    Discover rides from the community.

    Authorization:
        Any authenticated user.

    Important:
        This does NOT behave like the host's "my rides" API.

        Host API:
            current_user.id -> only that user's rides

        Community API:
            current_user.id -> authorization only
            database -> discover rides from the community
    """

    query = _community_ride_query()

    # ─────────────────────────────────────────────────────────────
    # Community ownership boundary
    # ─────────────────────────────────────────────────────────────

    if exclude_own_rides:
        query = query.where(
            Ride.host_user_id != current_user.id
        )

    # ─────────────────────────────────────────────────────────────
    # Only rides that can appear in discovery
    # ─────────────────────────────────────────────────────────────

    query = query.where(
        Ride.status != "cancelled"
    )

    # ─────────────────────────────────────────────────────────────
    # Vehicle filters
    # ─────────────────────────────────────────────────────────────

    if vehicle_category:
        query = query.where(
            Ride.vehicle.has(
                Vehicle.vehicle_category
                == vehicle_category
            )
        )

    if vehicle_subtype:
        query = query.where(
            Ride.vehicle.has(
                Vehicle.vehicle_subtype
                == vehicle_subtype
            )
        )

    # ─────────────────────────────────────────────────────────────
    # Ride features
    # ─────────────────────────────────────────────────────────────

    if women_only:
        query = query.where(
            Ride.is_women_only.is_(True)
        )

    if flexible_pickup:
        query = query.where(
            Ride.flexible_pickup.is_(True)
        )

    if allow_luggage:
        query = query.where(
            Ride.allow_luggage.is_(True)
        )

    if allow_pets:
        query = query.where(
            Ride.allow_pets.is_(True)
        )

    if allow_music:
        query = query.where(
            Ride.allow_music.is_(True)
        )

    if ac:
        query = query.where(
            Ride.is_ac.is_(True)
        )

    # ─────────────────────────────────────────────────────────────
    # Seats
    # ─────────────────────────────────────────────────────────────

    query = query.where(
        Ride.available_seats >= min_seats
    )

    # ─────────────────────────────────────────────────────────────
    # Departure window
    # ─────────────────────────────────────────────────────────────

    if departure_from:
        query = query.where(
            Ride.departure_time >= departure_from
        )

    if departure_to:
        query = query.where(
            Ride.departure_time <= departure_to
        )

    # ─────────────────────────────────────────────────────────────
    # Ordering / pagination
    # ─────────────────────────────────────────────────────────────

    query = (
        query
        .order_by(
            Ride.departure_time.asc()
        )
        .offset(offset)
        .limit(limit)
    )

    rides = db.scalars(
        query
    ).all()

    # ─────────────────────────────────────────────────────────────
    # Synchronize lifecycle status
    # ─────────────────────────────────────────────────────────────

    changed = False

    for ride in rides:
        if _sync_ride_status(ride):
            changed = True

    if changed:
        db.commit()

    return [
        _build_card_response(ride)
        for ride in rides
    ]


# ═════════════════════════════════════════════════════════════════════════════
# GET /community-rides/{ride_id}
# ═════════════════════════════════════════════════════════════════════════════


@router.get(
    "/{ride_id}",
    response_model=CommunityRideDetailResponse,
    summary="Get community ride details",
    description=(
        "Returns the complete public details of a community ride. "
        "Registration number is intentionally excluded."
    ),
)
def get_community_ride_details(
    ride_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Return one community ride.

    Any authenticated user can view another user's published ride.

    The response contains:
        - host public profile
        - host rating
        - behavioural rating
        - completed ride count
        - origin
        - destination
        - stops
        - route geometry
        - route legs
        - vehicle category
        - vehicle subtype
        - vehicle model
        - vehicle colour
        - seating capacity
        - fare
        - available seats
        - ride preferences
        - lifecycle status

    It does NOT contain:
        - vehicle registration number
        - host phone number
        - host email
        - authentication identifiers
        - private verification information
    """

    query = (
        _community_ride_query()
        .where(
            Ride.id == ride_id
        )
    )

    ride = db.scalars(
        query
    ).first()

    if ride is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Community ride not found.",
        )

    # Cancelled rides should not be discoverable through
    # the community detail endpoint.
    if ride.status == "cancelled":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Community ride is no longer available.",
        )

    changed = _sync_ride_status(
        ride
    )

    if changed:
        db.commit()

    return _build_detail_response(
        ride
    )


# ═════════════════════════════════════════════════════════════════════════════
# GET /community-rides/test
# ═════════════════════════════════════════════════════════════════════════════


@router.get(
    "/test",
    summary="Test Community Rides API",
)
def test_community_rides(
    current_user: User = Depends(get_current_user),
):
    """
    Simple authenticated endpoint used to verify that the
    Community Rides router is correctly registered.
    """

    return {
        "status": "success",
        "message": "Community Rides API is working",
    }

