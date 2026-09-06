from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models.aadhar_document import Aadhaar
from app.db.models.driving_licence import DrivingLicence
from app.db.models.vehicle_rc import VehicleRC
from app.db.models.ride import Ride
from app.db.models.user import User
from app.db.models.host_stat import HostStat
from app.db.schemas.ride import RideCancelResponse, RideCreateRequest, RideResponse
from app.dependencies.auth import get_current_user

router = APIRouter(prefix="/rides", tags=["Rides"])


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _build_response(ride: Ride, host: User | None) -> RideResponse:
    """Map ORM Ride + User objects → RideResponse schema."""
    return RideResponse(
        ride_id=ride.id,
        host_id=ride.host_id,
        host_name=host.full_name if host else None,
        host_avatar=host.avatar_url if host else None,
        origin_name=ride.origin_name,
        origin_lat=ride.origin_lat,
        origin_lng=ride.origin_lng,
        destination_name=ride.destination_name,
        destination_lat=ride.destination_lat,
        destination_lng=ride.destination_lng,
        departure_time=ride.departure_time,
        available_seats=ride.available_seats,
        fare_per_seat=ride.fare_per_seat,
        vehicle_model=ride.vehicle_model,
        vehicle_number=ride.vehicle_number,
        is_women_only=ride.is_women_only,
        democratic_consent=ride.democratic_consent,
        status=ride.status,
        created_at=ride.created_at,
    )


# ─── POST /rides — Publish a commute route ────────────────────────────────────

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
    A verified host publishes a commute route.

    Gate: user must have Aadhaar verified.
    (DL + RC not required yet — relaxed during MVP so testing is easy.)
    """

    # Fetch local DB User using Supabase User UUID
    db_user = (
        db.query(User)
        .filter(User.supabase_user_id == current_user.id)
        .first()
    )

    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found. Please sync your account first.",
        )

    # ── Verification gate: All 3 documents required ──
    aadhaar = db.query(Aadhaar).filter(Aadhaar.user_id == db_user.id).first()
    dl = db.query(DrivingLicence).filter(DrivingLicence.user_id == db_user.id).first()
    rc = db.query(VehicleRC).filter(VehicleRC.user_id == db_user.id).first()

    is_aadhaar_ok = aadhaar is not None and aadhaar.aadhaar_verified
    is_dl_ok = dl is not None and dl.dl_verified
    is_rc_ok = rc is not None and rc.rc_verified

    if not (is_aadhaar_ok and is_dl_ok and is_rc_ok):
        unverified_docs = []
        if not is_aadhaar_ok: unverified_docs.append("Aadhaar")
        if not is_dl_ok: unverified_docs.append("Driving Licence")
        if not is_rc_ok: unverified_docs.append("Vehicle RC")

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"All 3 documents must be verified to offer rides. Pending: {', '.join(unverified_docs)}.",
        )

    # ── Create ride row ──
    ride = Ride(
        host_id=db_user.supabase_user_id,
        origin_name=payload.origin_name,
        origin_lat=payload.origin_lat,
        origin_lng=payload.origin_lng,
        destination_name=payload.destination_name,
        destination_lat=payload.destination_lat,
        destination_lng=payload.destination_lng,
        departure_time=payload.departure_time,
        available_seats=payload.available_seats,
        fare_per_seat=payload.fare_per_seat,
        vehicle_model=payload.vehicle_model,
        vehicle_number=payload.vehicle_number,
        is_women_only=payload.is_women_only,
        democratic_consent=payload.democratic_consent,
        status="active",
    )

    db.add(ride)

    # ── Update Host Stats ──
    host_stat = db.query(HostStat).filter(HostStat.user_id == db_user.id).first()
    if host_stat is None:
        host_stat = HostStat(user_id=db_user.id)
        db.add(host_stat)

    host_stat.shared_commutes_count += 1
    host_stat.fuel_recovered_inr += payload.fare_per_seat * payload.available_seats
    host_stat.co2_saved_kg += 4.2

    db.commit()
    db.refresh(ride)

    return _build_response(ride, db_user)


# ─── GET /rides — Browse all active rides (passenger view) ───────────────────

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
    Returns all rides with status='active', posted by any host.
    Future: filter by proximity to passenger origin/destination.
    """

    rides = (
        db.query(Ride)
        .filter(Ride.status == "active")
        .order_by(Ride.departure_time.asc())
        .all()
    )

    result = []
    for ride in rides:
        host = (
            db.query(User)
            .filter(User.supabase_user_id == ride.host_id)
            .first()
        )
        result.append(_build_response(ride, host))

    return result


# ─── GET /rides/my — Rides posted by the current host ────────────────────────

@router.get(
    "/my",
    response_model=List[RideResponse],
    summary="List rides posted by current user",
)
def list_my_rides(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> List[RideResponse]:
    """Returns all rides (any status) that this host has posted."""

    db_user = (
        db.query(User)
        .filter(User.supabase_user_id == current_user.id)
        .first()
    )

    if not db_user:
        return []

    rides = (
        db.query(Ride)
        .filter(Ride.host_id == db_user.supabase_user_id)
        .order_by(Ride.created_at.desc())
        .all()
    )

    return [_build_response(ride, db_user) for ride in rides]


# ─── PATCH /rides/{ride_id}/cancel — Cancel a ride ───────────────────────────

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
    """Soft-cancel: sets status to 'cancelled'. Only the posting host can cancel."""

    ride = db.query(Ride).filter(Ride.id == ride_id).first()

    if not ride:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Ride {ride_id} not found.",
        )

    if ride.host_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only cancel your own rides.",
        )

    if ride.status != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ride is already '{ride.status}' and cannot be cancelled.",
        )

    ride.status = "cancelled"
    db.commit()

    return RideCancelResponse(
        ride_id=ride.id,
        status="cancelled",
        message="Ride successfully cancelled.",
    )

