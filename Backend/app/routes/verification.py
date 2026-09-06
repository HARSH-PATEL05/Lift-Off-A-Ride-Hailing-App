from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.dependencies.auth import get_current_user
from app.db.database import get_db

from app.db.models.user import User
from app.db.models.aadhar_document import Aadhaar
from app.db.models.driving_licence import DrivingLicence
from app.db.models.vehicle_rc import VehicleRC
from app.db.models.host_stat import HostStat

from app.db.schemas.verification import (
    AadhaarVerificationRequest,
    DrivingLicenceVerificationRequest,
    VehicleRCVerificationRequest,
)

from app.services.Authentication.aadhaar.provider import (
    get_aadhaar_provider,
)

from app.services.Authentication.driving_licence.provider import (
    get_driving_licence_provider,
)

from app.services.Authentication.vehicle_rc.provider import (
    get_vehicle_rc_provider,
)
from app.core.security import sensitive_data_encryption


def _build_user_profile_response(db: Session, user: User) -> dict:
    """Helper to return accurate live status of all 3 verification documents."""
    aadhaar = db.query(Aadhaar).filter(Aadhaar.user_id == user.id).first()
    dl = db.query(DrivingLicence).filter(DrivingLicence.user_id == user.id).first()
    rc = db.query(VehicleRC).filter(VehicleRC.user_id == user.id).first()
    stat = db.query(HostStat).filter(HostStat.user_id == user.id).first()

    aadhaar_verified = aadhaar.aadhaar_verified if aadhaar else False
    dl_verified = dl.dl_verified if dl else False
    rc_verified = rc.rc_verified if rc else False

    masked_aadhaar = f"XXXX-XXXX-{aadhaar.aadhaar_last_four}" if aadhaar else None

    return {
        "user_id": str(user.supabase_user_id),
        "email": user.email,
        "full_name": user.full_name,
        "avatar_url": user.avatar_url,
        "aadhaar_verified": aadhaar_verified,
        "driving_licence_verified": dl_verified,
        "dl_verified": dl_verified,
        "rc_verified": rc_verified,
        "vehicle_rc_verified": rc_verified,
        "masked_aadhaar": masked_aadhaar,
        "fuel_recovered_inr": stat.fuel_recovered_inr if stat else 0.0,
        "shared_commutes_count": stat.shared_commutes_count if stat else 0,
        "co2_saved_kg": stat.co2_saved_kg if stat else 0.0,
        "created_at": user.created_at.isoformat(),
    }


router = APIRouter(
    prefix="/verification",
    tags=["Verification"],
)


@router.post("/aadhaar")
async def verify_aadhaar(
    request: AadhaarVerificationRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Verify Aadhaar for the currently authenticated user.

    Flow:
    1. Authenticate JWT
    2. Find local user
    3. Call verification provider
    4. Encrypt Aadhaar
    5. Create/update Aadhaar document
    """

    print("\n========== AADHAAR VERIFICATION REQUEST ==========")

    # ─────────────────────────────────────────────
    # Find Local User
    # ─────────────────────────────────────────────

    user = (
        db.query(User)
        .filter(
            User.supabase_user_id == current_user.id
        )
        .first()
    )

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="Local user profile not found",
        )

    print("Local User ID:", user.id)
    print("Supabase User ID:", current_user.id)

    # ─────────────────────────────────────────────
    # Get Verification Provider
    # ─────────────────────────────────────────────

    provider = get_aadhaar_provider()

    # Verify Aadhaar
    result = await provider.verify(
        request.aadhaar_number
    )

    print("\n---------- PROVIDER RESULT ----------")
    print(result)

    # ─────────────────────────────────────────────
    # Stop if verification failed
    # ─────────────────────────────────────────────

    if not result["verified"]:

        print("❌ Aadhaar verification failed")

        return {
            "verified": False,
            "message": result["message"],
        }

    # ─────────────────────────────────────────────
    # Encrypt Aadhaar
    # ─────────────────────────────────────────────

    encrypted_aadhaar = (
        sensitive_data_encryption.encrypt(
            request.aadhaar_number
        )
    )

    aadhaar_last_four = (
        request.aadhaar_number[-4:]
    )

    print("\n---------- AADHAAR PROCESSING ----------")
    print("Aadhaar verification: SUCCESS")
    print("Last four digits:", aadhaar_last_four)
    print("Aadhaar encrypted successfully")

    # ─────────────────────────────────────────────
    # Check Existing Aadhaar Record
    # ─────────────────────────────────────────────

    aadhaar_document = (
        db.query(Aadhaar)
        .filter(
            Aadhaar.user_id == user.id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Create New Aadhaar Record
    # ─────────────────────────────────────────────

    if aadhaar_document is None:

        print("\n🆕 Creating Aadhaar document record")

        aadhaar_document = Aadhaar(
            user_id=user.id,
            aadhaar_encrypted=encrypted_aadhaar,
            aadhaar_last_four=aadhaar_last_four,
            aadhaar_verified=True,
            verification_reference=result.get(
                "verification_reference"
            ),
        )

        db.add(aadhaar_document)

    # ─────────────────────────────────────────────
    # Update Existing Aadhaar Record
    # ─────────────────────────────────────────────

    else:

        print("\n🔄 Updating existing Aadhaar document")

        aadhaar_document.aadhaar_encrypted = (
            encrypted_aadhaar
        )

        aadhaar_document.aadhaar_last_four = (
            aadhaar_last_four
        )

        aadhaar_document.aadhaar_verified = True

        aadhaar_document.verification_reference = (
            result.get("verification_reference")
        )

    # ─────────────────────────────────────────────
    # Save Database Changes
    # ─────────────────────────────────────────────

    db.commit()

    db.refresh(aadhaar_document)

    print("\n========== DATABASE UPDATED ==========")

    print(
        "Document ID:",
        aadhaar_document.id,
    )

    print(
        "Aadhaar Verified:",
        aadhaar_document.aadhaar_verified,
    )

    print(
        "Verification Reference:",
        aadhaar_document.verification_reference,
    )

    print("======================================\n")

    # ─────────────────────────────────────────────
    # Return Response
    # ─────────────────────────────────────────────

    return {
        "verified": True,
        "message": result["message"],
        "user_profile": _build_user_profile_response(db, user),
    }

@router.post("/driving-licence")
async def verify_driving_licence(
    request: DrivingLicenceVerificationRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):

    print("\n========== DRIVING LICENCE VERIFICATION ==========")

    # ─────────────────────────────────────────────
    # Find Local User
    # ─────────────────────────────────────────────

    user = (
        db.query(User)
        .filter(
            User.supabase_user_id == current_user.id
        )
        .first()
    )

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="Local user profile not found",
        )

    print("Local User ID:", user.id)

    # ─────────────────────────────────────────────
    # Get DL Verification Provider
    # ─────────────────────────────────────────────

    provider = get_driving_licence_provider()

    result = await provider.verify(
        request.licence_number
    )

    print("\n---------- PROVIDER RESULT ----------")
    print(result)

    # ─────────────────────────────────────────────
    # Stop if verification failed
    # ─────────────────────────────────────────────

    if not result["verified"]:

        return {
            "verified": False,
            "message": result["message"],
        }

    # ─────────────────────────────────────────────
    # Encrypt Driving Licence Number
    # ─────────────────────────────────────────────

    encrypted_dl = (
        sensitive_data_encryption.encrypt(
            request.licence_number
        )
    )

    dl_last_four = request.licence_number[-4:]

    print("DL encrypted successfully")
    print("Last four digits:", dl_last_four)

    # ─────────────────────────────────────────────
    # Check Existing DL Record
    # ─────────────────────────────────────────────

    dl_document = (
        db.query(DrivingLicence)
        .filter(
            DrivingLicence.user_id == user.id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Create New DL Record
    # ─────────────────────────────────────────────

    if dl_document is None:

        print("🆕 Creating Driving Licence record")

        dl_document = DrivingLicence(
            user_id=user.id,
            dl_encrypted=encrypted_dl,
            dl_last_four=dl_last_four,
            dl_verified=True,
            verification_reference=result.get(
                 "verification_reference"
            ),
        )

        db.add(dl_document)

    # ─────────────────────────────────────────────
    # Update Existing DL Record
    # ─────────────────────────────────────────────

    else:

        print("🔄 Updating Driving Licence record")

        dl_document.dl_encrypted = encrypted_dl
        dl_document.dl_last_four = dl_last_four
        dl_document.dl_verified = True

        dl_document.verification_reference = result.get(
            "verification_reference"
        )

    # ─────────────────────────────────────────────
    # Save Database
    # ─────────────────────────────────────────────

    db.commit()

    db.refresh(dl_document)

    print("\n========== DL DATABASE UPDATED ==========")
    print("Document ID:", dl_document.id)
    print("DL Verified:", dl_document.dl_verified)
    print("========================================\n")

    # ─────────────────────────────────────────────
    # Return Response
    # ─────────────────────────────────────────────

    return {
        "verified": True,
        "message": result["message"],
        "user_profile": _build_user_profile_response(db, user),
    }
@router.post("/vehicle-rc")
async def verify_vehicle_rc(
    request: VehicleRCVerificationRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):

    print("\n========== VEHICLE RC VERIFICATION ==========")

    # ─────────────────────────────────────────────
    # Find Local User
    # ─────────────────────────────────────────────

    user = (
        db.query(User)
        .filter(
            User.supabase_user_id == current_user.id
        )
        .first()
    )

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="Local user profile not found",
        )

    print("Local User ID:", user.id)

    # ─────────────────────────────────────────────
    # Get RC Verification Provider
    # ─────────────────────────────────────────────

    provider = get_vehicle_rc_provider()

    result = await provider.verify(
        request.rc_number
    )

    print("\n---------- PROVIDER RESULT ----------")
    print(result)

    # ─────────────────────────────────────────────
    # Stop if verification failed
    # ─────────────────────────────────────────────

    if not result["verified"]:
        return {
            "verified": False,
            "message": result["message"],
        }

    # ─────────────────────────────────────────────
    # Encrypt RC Number
    # ─────────────────────────────────────────────

    encrypted_rc = sensitive_data_encryption.encrypt(
        request.rc_number
    )

    rc_last_four = request.rc_number[-4:]

    print("RC encrypted successfully")
    print("Last four digits:", rc_last_four)

    # ─────────────────────────────────────────────
    # Check Existing RC Record
    # ─────────────────────────────────────────────

    rc_document = (
        db.query(VehicleRC)
        .filter(
            VehicleRC.user_id == user.id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Create New RC Record
    # ─────────────────────────────────────────────

    if rc_document is None:

        print("🆕 Creating Vehicle RC record")

        rc_document = VehicleRC(
            user_id=user.id,
            rc_encrypted=encrypted_rc,
            rc_last_four=rc_last_four,
            rc_verified=True,
            verification_reference=result.get(
                "verification_reference"
            ),
        )

        db.add(rc_document)

    # ─────────────────────────────────────────────
    # Update Existing RC Record
    # ─────────────────────────────────────────────

    else:

        print("🔄 Updating Vehicle RC record")

        rc_document.rc_encrypted = encrypted_rc

        rc_document.rc_last_four = rc_last_four

        rc_document.rc_verified = True

        rc_document.verification_reference = (
            result.get(
                "verification_reference"
            )
        )

    # ─────────────────────────────────────────────
    # Save Database
    # ─────────────────────────────────────────────

    db.commit()

    db.refresh(rc_document)

    print("\n========== RC DATABASE UPDATED ==========")
    print("Document ID:", rc_document.id)
    print(
        "RC Verified:",
        rc_document.rc_verified,
    )
    print("========================================\n")

    # ─────────────────────────────────────────────
    # Return Response
    # ─────────────────────────────────────────────

    return {
        "verified": True,
        "message": result["message"],
        "user_profile": _build_user_profile_response(db, user),
    }