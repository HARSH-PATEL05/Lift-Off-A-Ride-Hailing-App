from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.dependencies.auth import get_current_user
from app.db.database import get_db

from app.db.models.user import User
from app.db.models.aadhar_document import Aadhaar
from app.db.models.driving_licence import DrivingLicence
from app.db.models.vehicle_rc import VehicleRC


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


@router.post("/sync")
async def sync_user(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Synchronize the authenticated Supabase user
    with the local PostgreSQL database and return
    the complete user profile.
    """

    # ─────────────────────────────────────────────
    # Extract Supabase User Information
    # ─────────────────────────────────────────────

    supabase_user_id = current_user.id
    email = current_user.email

    user_metadata = current_user.user_metadata or {}

    full_name = (
        user_metadata.get("full_name")
        or user_metadata.get("name")
    )

    avatar_url = (
        user_metadata.get("avatar_url")
        or user_metadata.get("picture")
    )

    print("\n========== AUTH SYNC STARTED ==========")

    print("Supabase User ID:", supabase_user_id)
    print("Email:", email)
    print("Full Name:", full_name)
    print("Avatar URL:", avatar_url)

    # ─────────────────────────────────────────────
    # Find Local User
    # ─────────────────────────────────────────────

    user = (
        db.query(User)
        .filter(User.supabase_user_id == supabase_user_id)
        .first()
    )

    # ─────────────────────────────────────────────
    # Create New User
    # ─────────────────────────────────────────────

    if user is None:

        print("\n🆕 NEW USER DETECTED")
        print("Creating user in PostgreSQL...")

        user = User(
            supabase_user_id=supabase_user_id,
            email=email,
            full_name=full_name,
            avatar_url=avatar_url,
        )

        db.add(user)
        db.commit()
        db.refresh(user)

        print("✅ USER CREATED SUCCESSFULLY")
        print("Local User ID:", user.id)

    # ─────────────────────────────────────────────
    # Existing User
    # ─────────────────────────────────────────────

    else:

        print("\n👤 EXISTING USER FOUND")
        print("Local User ID:", user.id)

        # Update profile information from Supabase
        user.full_name = full_name
        user.avatar_url = avatar_url

        db.commit()
        db.refresh(user)

        print("✅ USER INFORMATION UPDATED")

    # ─────────────────────────────────────────────
    # Aadhaar Document
    # ─────────────────────────────────────────────

    aadhaar_document = (
        db.query(Aadhaar)
        .filter(Aadhaar.user_id == user.id)
        .first()
    )

    if aadhaar_document is not None:

        aadhaar_verified = aadhaar_document.aadhaar_verified

        # Example:
        # 1234
        # ↓
        # XXXX-XXXX-1234
        masked_aadhaar = (
            f"XXXX-XXXX-{aadhaar_document.aadhaar_last_four}"
        )

    else:

        aadhaar_verified = False
        masked_aadhaar = None

    # ─────────────────────────────────────────────
    # Driving Licence Document
    # ─────────────────────────────────────────────

    driving_licence_document = (
        db.query(DrivingLicence)
        .filter(DrivingLicence.user_id == user.id)
        .first()
    )

    driving_licence_verified = (
        driving_licence_document.driving_licence_verified
        if driving_licence_document is not None
        else False
    )

    # ─────────────────────────────────────────────
    # Vehicle RC Document
    # ─────────────────────────────────────────────

    vehicle_rc_document = (
        db.query(VehicleRC)
        .filter(VehicleRC.user_id == user.id)
        .first()
    )

    rc_verified = (
        vehicle_rc_document.rc_verified
        if vehicle_rc_document is not None
        else False
    )

    # ─────────────────────────────────────────────
    # Debug Output
    # ─────────────────────────────────────────────

    print("\n---------- VERIFICATION STATUS ----------")

    print("Aadhaar Verified:", aadhaar_verified)
    print("Masked Aadhaar:", masked_aadhaar)

    print(
        "Driving Licence Verified:",
        driving_licence_verified,
    )

    print("RC Verified:", rc_verified)

    print("=========================================\n")

    # ─────────────────────────────────────────────
    # Return Complete User Profile
    # ─────────────────────────────────────────────

    return {
        "user_id": user.supabase_user_id,

        "email": user.email,

        "full_name": user.full_name,

        "avatar_url": user.avatar_url,

        "aadhaar_verified": aadhaar_verified,

        "driving_licence_verified": driving_licence_verified,

        "rc_verified": rc_verified,

        "masked_aadhaar": masked_aadhaar,

        "created_at": user.created_at.isoformat(),
    }