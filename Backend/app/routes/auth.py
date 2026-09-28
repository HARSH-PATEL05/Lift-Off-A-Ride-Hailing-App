from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies.auth import get_current_user
from app.db.database import get_db

from app.db.models.user import User
from app.db.models.aadhar_document import Aadhaar
from app.db.models.driving_licence import DrivingLicence
from app.db.models.vehicle import Vehicle
from app.db.models.user_vehicle import UserVehicle
from app.db.models.vehicle_rc import VehicleRC
from app.db.models.host_stat import HostStat


# ============================================================
# TEMPORARY DEVELOPMENT CONFIGURATION
# ============================================================
#
# True:
#   /auth/dev/verify-phone/{phone_number} is available.
#
# False:
#   Development phone verification endpoint is disabled.
#
# IMPORTANT:
# Set this to False before production.
#
DEV_PHONE_VERIFICATION_ENABLED = True


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)

# ============================================================
# USER PROFILE ROUTER
# ============================================================

user_router = APIRouter(
    tags=["User Profile"],
)


def _build_profile_dict(
    db: Session,
    user: User,
) -> dict:
    """
    Construct complete user profile payload including
    phone information, document verification and host stats.

    Vehicle RC verification is considered complete when
    the user has at least one active vehicle with a
    verified RC.
    """

    # ─────────────────────────────────────────────
    # Aadhaar
    # ─────────────────────────────────────────────

    aadhaar_doc = (
        db.query(Aadhaar)
        .filter(
            Aadhaar.user_id == user.id
        )
        .first()
    )

    aadhaar_verified = (
        aadhaar_doc.aadhaar_verified
        if aadhaar_doc
        else False
    )

    masked_aadhaar = (
        f"XXXX-XXXX-{aadhaar_doc.aadhaar_last_four}"
        if aadhaar_doc and aadhaar_doc.aadhaar_last_four
        else None
    )

    # ─────────────────────────────────────────────
    # Driving Licence
    # ─────────────────────────────────────────────

    dl_doc = (
        db.query(DrivingLicence)
        .filter(
            DrivingLicence.user_id == user.id
        )
        .first()
    )

    dl_verified = (
        dl_doc.dl_verified
        if dl_doc
        else False
    )

    # ─────────────────────────────────────────────
    # Masked Driving Licence
    # ─────────────────────────────────────────────

    masked_driving_licence = (
        f"XXXX-XXXX-{dl_doc.dl_last_four}"
        if dl_doc and dl_doc.dl_last_four
        else None
    )

    # ─────────────────────────────────────────────
    # Vehicle RC
    #
    # User
    #   ↓
    # UserVehicle
    #   ↓
    # Vehicle
    #   ↓
    # VehicleRC
    #
    # RC verification is true if the user has at
    # least one ACTIVE vehicle with a VERIFIED RC.
    # ─────────────────────────────────────────────

    rc_doc = (
        db.query(VehicleRC)
        .join(
            Vehicle,
            VehicleRC.vehicle_id == Vehicle.id,
        )
        .join(
            UserVehicle,
            UserVehicle.vehicle_id == Vehicle.id,
        )
        .filter(
            UserVehicle.user_id == user.id,
            UserVehicle.is_active == True,
            VehicleRC.rc_verified == True,
        )
        .first()
    )

    rc_verified = rc_doc is not None

    # ─────────────────────────────────────────────
    # Host Performance Stats
    # ─────────────────────────────────────────────

    host_stat = (
        db.query(HostStat)
        .filter(
            HostStat.user_id == user.id
        )
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

    # ─────────────────────────────────────────────
    # Profile Response
    # ─────────────────────────────────────────────

    return {
        # ─────────────────────────────────────────
        # Basic User Information
        # ─────────────────────────────────────────

        "user_id": user.supabase_user_id,
        "email": user.email,
        "full_name": user.full_name,
        "avatar_url": user.avatar_url,

        # ─────────────────────────────────────────
        # Phone
        # ─────────────────────────────────────────

        "phone_number": user.phone_number,
        "phone_verified": user.phone_verified,

        # ─────────────────────────────────────────
        # Aadhaar
        # ─────────────────────────────────────────

        "aadhaar_verified": aadhaar_verified,

        # ─────────────────────────────────────────
        # Driving Licence
        # ─────────────────────────────────────────

        "driving_licence_verified": dl_verified,
        "dl_verified": dl_verified,

        # ─────────────────────────────────────────
        # Vehicle RC
        # ─────────────────────────────────────────

        "rc_verified": rc_verified,
        "vehicle_rc_verified": rc_verified,

        # ─────────────────────────────────────────
        # Masked Aadhaar
        # ─────────────────────────────────────────

        "masked_aadhaar": masked_aadhaar,

        # ─────────────────────────────────────────
        # Masked Driving Licence
        # ─────────────────────────────────────────

        "masked_driving_licence": masked_driving_licence,

        # ─────────────────────────────────────────
        # Host Stats
        # ─────────────────────────────────────────

        "fuel_recovered_inr": (
            host_stat.fuel_recovered_inr
        ),

        "shared_commutes_count": (
            host_stat.shared_commutes_count
        ),

        "co2_saved_kg": (
            host_stat.co2_saved_kg
        ),

        # ─────────────────────────────────────────
        # User
        # ─────────────────────────────────────────

        "created_at": user.created_at.isoformat(),
    }


# ═══════════════════════════════════════════════════════════════
# AUTHENTICATION
# ═══════════════════════════════════════════════════════════════


@router.post("/sync")
async def sync_user(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Synchronize the authenticated Supabase user
    with local PostgreSQL and return profile.

    Supabase remains the source of truth for phone
    ownership verification.

    The local LiftOff database stores the confirmed
    phone number and verification state so that the
    application profile can use it.
    """

    # ─────────────────────────────────────────────
    # Supabase User Information
    # ─────────────────────────────────────────────

    supabase_user_id = current_user.id
    email = current_user.email

    user_metadata = (
        current_user.user_metadata or {}
    )

    full_name = (
        user_metadata.get("full_name")
        or user_metadata.get("name")
    )

    avatar_url = (
        user_metadata.get("avatar_url")
        or user_metadata.get("picture")
    )

    # ─────────────────────────────────────────────
    # Supabase Phone Verification
    #
    # REAL PRODUCTION FLOW:
    #
    # current_user.phone
    # current_user.phone_confirmed_at
    #
    # are used to determine verification.
    # ─────────────────────────────────────────────

    supabase_phone = getattr(
        current_user,
        "phone",
        None,
    )

    phone_confirmed_at = getattr(
        current_user,
        "phone_confirmed_at",
        None,
    )

    phone_is_verified = (
        bool(supabase_phone)
        and phone_confirmed_at is not None
    )

    # ─────────────────────────────────────────────
    # Find Local User
    # ─────────────────────────────────────────────

    user = (
        db.query(User)
        .filter(
            User.supabase_user_id
            == supabase_user_id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Create Local User
    # ─────────────────────────────────────────────

    if user is None:

        user = User(
            supabase_user_id=supabase_user_id,
            email=email,
            full_name=full_name,
            avatar_url=avatar_url,
        )

        # Real Supabase phone verification.
        if phone_is_verified:
            user.phone_number = supabase_phone
            user.phone_verified = True

        db.add(user)

        db.commit()

        db.refresh(user)

    # ─────────────────────────────────────────────
    # Update Existing User
    # ─────────────────────────────────────────────

    else:

        user.full_name = full_name
        user.avatar_url = avatar_url

        # Real Supabase phone verification.
        if phone_is_verified:
            user.phone_number = supabase_phone
            user.phone_verified = True

        db.commit()

        db.refresh(user)

    # ─────────────────────────────────────────────
    # Return Profile
    # ─────────────────────────────────────────────

    return _build_profile_dict(
        db,
        user,
    )


# ═══════════════════════════════════════════════════════════════
# TEMPORARY DEVELOPMENT PHONE VERIFICATION
# ═══════════════════════════════════════════════════════════════


@router.post(
    "/dev/verify-phone/{phone_number:path}"
)
async def dev_verify_phone(
    phone_number: str,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    TEMPORARY DEVELOPMENT-ONLY PHONE VERIFICATION.

    This endpoint exists only while real Supabase/Twilio
    SMS verification is being integrated.

    Any 6-digit OTP is accepted by Flutter before reaching
    this endpoint.

    The backend then stores the supplied phone number and
    marks it as verified.

    IMPORTANT:
    This endpoint must be disabled before production.
    """

    if not DEV_PHONE_VERIFICATION_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Development phone verification is disabled.",
        )

    # ─────────────────────────────────────────────
    # Validate Phone
    # ─────────────────────────────────────────────

    normalized_phone = phone_number.strip()

    if not normalized_phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number is required.",
        )

    # ─────────────────────────────────────────────
    # Basic Phone Validation
    #
    # Supports:
    # +919XXXXXXXXX
    # 919XXXXXXXXX
    # 10-digit Indian number
    # ─────────────────────────────────────────────

    if normalized_phone.startswith("+"):
        phone_digits = normalized_phone[1:]
    else:
        phone_digits = normalized_phone

    if (
        not phone_digits.isdigit()
        or len(phone_digits) < 10
        or len(phone_digits) > 15
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid phone number.",
        )

    # Normalize a plain 10-digit Indian number.
    if len(phone_digits) == 10:
        normalized_phone = f"+91{phone_digits}"
    elif normalized_phone.startswith("+"):
        normalized_phone = f"+{phone_digits}"
    else:
        normalized_phone = phone_digits

    # ─────────────────────────────────────────────
    # Find Local User
    # ─────────────────────────────────────────────

    user = (
        db.query(User)
        .filter(
            User.supabase_user_id
            == current_user.id
        )
        .first()
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                "User profile not found. "
                "Please sync your account first."
            ),
        )

    # ─────────────────────────────────────────────
    # Prevent Duplicate Phone Numbers
    #
    # phone_number is UNIQUE in the database.
    # ─────────────────────────────────────────────

    existing_user = (
        db.query(User)
        .filter(
            User.phone_number == normalized_phone,
            User.id != user.id,
        )
        .first()
    )

    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "This phone number is already associated "
                "with another LiftOff account."
            ),
        )

    # ─────────────────────────────────────────────
    # TEMPORARY VERIFICATION
    # ─────────────────────────────────────────────

    user.phone_number = normalized_phone
    user.phone_verified = True

    db.commit()
    db.refresh(user)

    return _build_profile_dict(
        db,
        user,
    )


# ═══════════════════════════════════════════════════════════════
# USER PROFILE
# ═══════════════════════════════════════════════════════════════


@user_router.get("/api/user/profile")
async def get_user_profile(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Fetch current user's profile and verification status,
    including phone information.
    """

    # ─────────────────────────────────────────────
    # Find Local User
    # ─────────────────────────────────────────────

    user = (
        db.query(User)
        .filter(
            User.supabase_user_id
            == current_user.id
        )
        .first()
    )

    if not user:

        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                "User profile not found. "
                "Please sync your account first."
            ),
        )

    # ─────────────────────────────────────────────
    # Return Profile
    # ─────────────────────────────────────────────

    return _build_profile_dict(
        db,
        user,
    )