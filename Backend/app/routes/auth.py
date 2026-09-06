from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies.auth import get_current_user
from app.db.database import get_db

from app.db.models.user import User
from app.db.models.aadhar_document import Aadhaar
from app.db.models.driving_licence import DrivingLicence
from app.db.models.vehicle_rc import VehicleRC
from app.db.models.host_stat import HostStat


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)

user_router = APIRouter(
    tags=["User Profile"],
)


def _build_profile_dict(db: Session, user: User) -> dict:
    """Construct complete user profile payload including document verification and host stats."""

    # Aadhaar
    aadhaar_doc = (
        db.query(Aadhaar)
        .filter(Aadhaar.user_id == user.id)
        .first()
    )
    aadhaar_verified = aadhaar_doc.aadhaar_verified if aadhaar_doc else False
    masked_aadhaar = f"XXXX-XXXX-{aadhaar_doc.aadhaar_last_four}" if aadhaar_doc else None

    # Driving Licence
    dl_doc = (
        db.query(DrivingLicence)
        .filter(DrivingLicence.user_id == user.id)
        .first()
    )
    dl_verified = dl_doc.dl_verified if dl_doc else False

    # Vehicle RC
    rc_doc = (
        db.query(VehicleRC)
        .filter(VehicleRC.user_id == user.id)
        .first()
    )
    rc_verified = rc_doc.rc_verified if rc_doc else False

    # Host Performance Stats
    host_stat = (
        db.query(HostStat)
        .filter(HostStat.user_id == user.id)
        .first()
    )
    if host_stat is None:
        host_stat = HostStat(
            user_id=user.id,
            fuel_recovered_inr=0.0,
            shared_commutes_count=0,
            co2_saved_kg=0.0,
        )
        db.add(host_stat)
        db.commit()
        db.refresh(host_stat)

    return {
        "user_id": user.supabase_user_id,
        "email": user.email,
        "full_name": user.full_name,
        "avatar_url": user.avatar_url,
        "aadhaar_verified": aadhaar_verified,
        "driving_licence_verified": dl_verified,
        "dl_verified": dl_verified,
        "rc_verified": rc_verified,
        "vehicle_rc_verified": rc_verified,
        "masked_aadhaar": masked_aadhaar,
        "fuel_recovered_inr": host_stat.fuel_recovered_inr,
        "shared_commutes_count": host_stat.shared_commutes_count,
        "co2_saved_kg": host_stat.co2_saved_kg,
        "created_at": user.created_at.isoformat(),
    }


@router.post("/sync")
async def sync_user(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Synchronize the authenticated Supabase user
    with local PostgreSQL and return profile.
    """

    supabase_user_id = current_user.id
    email = current_user.email
    user_metadata = current_user.user_metadata or {}

    full_name = user_metadata.get("full_name") or user_metadata.get("name")
    avatar_url = user_metadata.get("avatar_url") or user_metadata.get("picture")

    user = (
        db.query(User)
        .filter(User.supabase_user_id == supabase_user_id)
        .first()
    )

    if user is None:
        user = User(
            supabase_user_id=supabase_user_id,
            email=email,
            full_name=full_name,
            avatar_url=avatar_url,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        user.full_name = full_name
        user.avatar_url = avatar_url
        db.commit()
        db.refresh(user)

    return _build_profile_dict(db, user)


@user_router.get("/api/user/profile")
async def get_user_profile(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Fetch current user's profile and verification status."""

    user = (
        db.query(User)
        .filter(User.supabase_user_id == current_user.id)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found. Please sync your account first.",
        )

    return _build_profile_dict(db, user)