from fastapi import APIRouter, Depends, HTTPException
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


def _build_user_profile_response(
    db: Session,
    user: User,
) -> dict:
    """
    Build the current verification/profile status
    for the authenticated user.

    RC verification is considered complete when the
    user has at least one verified vehicle RC.
    """

    # ─────────────────────────────────────────────
    # Aadhaar
    # ─────────────────────────────────────────────

    aadhaar = (
        db.query(Aadhaar)
        .filter(
            Aadhaar.user_id == user.id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Driving Licence
    # ─────────────────────────────────────────────

    dl = (
        db.query(DrivingLicence)
        .filter(
            DrivingLicence.user_id == user.id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Vehicle RC
    #
    # New relationship:
    #
    # User
    #   ↓
    # UserVehicle
    #   ↓
    # Vehicle
    #   ↓
    # VehicleRC
    # ─────────────────────────────────────────────

    verified_rc = (
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

    # ─────────────────────────────────────────────
    # Host Stats
    # ─────────────────────────────────────────────

    stat = (
        db.query(HostStat)
        .filter(
            HostStat.user_id == user.id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Verification Status
    # ─────────────────────────────────────────────

    aadhaar_verified = (
        aadhaar.aadhaar_verified
        if aadhaar
        else False
    )

    dl_verified = (
        dl.dl_verified
        if dl
        else False
    )

    rc_verified = (
        verified_rc is not None
    )

    # ─────────────────────────────────────────────
    # Masked Aadhaar
    # ─────────────────────────────────────────────

    masked_aadhaar = (
        f"XXXX-XXXX-{aadhaar.aadhaar_last_four}"
        if aadhaar
        else None
    )

    # ─────────────────────────────────────────────
    # Return Profile
    # ─────────────────────────────────────────────

    return {
        "user_id": str(
            user.supabase_user_id
        ),
        "email": user.email,
        "full_name": user.full_name,
        "avatar_url": user.avatar_url,

        "aadhaar_verified": aadhaar_verified,

        "driving_licence_verified": dl_verified,
        "dl_verified": dl_verified,

        "rc_verified": rc_verified,
        "vehicle_rc_verified": rc_verified,

        "masked_aadhaar": masked_aadhaar,

        "fuel_recovered_inr": (
            stat.fuel_recovered_inr
            if stat
            else 0.0
        ),

        "shared_commutes_count": (
            stat.shared_commutes_count
            if stat
            else 0
        ),

        "co2_saved_kg": (
            stat.co2_saved_kg
            if stat
            else 0.0
        ),

        "created_at": user.created_at.isoformat(),
    }


router = APIRouter(
    prefix="/verification",
    tags=["Verification"],
)


# ═══════════════════════════════════════════════════════════════
# AADHAAR VERIFICATION
# ═══════════════════════════════════════════════════════════════


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

    print(
        "\n========== AADHAAR VERIFICATION REQUEST =========="
    )

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
            status_code=404,
            detail="Local user profile not found",
        )

    print(
        "Local User ID:",
        user.id,
    )

    print(
        "Supabase User ID:",
        current_user.id,
    )

    # ─────────────────────────────────────────────
    # Get Verification Provider
    # ─────────────────────────────────────────────

    provider = get_aadhaar_provider()

    result = await provider.verify(
        request.aadhaar_number
    )

    print(
        "\n---------- PROVIDER RESULT ----------"
    )
    print(result)

    # ─────────────────────────────────────────────
    # Stop if Verification Failed
    # ─────────────────────────────────────────────

    if not result["verified"]:

        print(
            "❌ Aadhaar verification failed"
        )

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

    print(
        "\n---------- AADHAAR PROCESSING ----------"
    )

    print(
        "Aadhaar verification: SUCCESS"
    )

    print(
        "Last four digits:",
        aadhaar_last_four,
    )

    print(
        "Aadhaar encrypted successfully"
    )

    # ─────────────────────────────────────────────
    # Check Existing Aadhaar
    # ─────────────────────────────────────────────

    aadhaar_document = (
        db.query(Aadhaar)
        .filter(
            Aadhaar.user_id == user.id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Create Aadhaar
    # ─────────────────────────────────────────────

    if aadhaar_document is None:

        print(
            "\n🆕 Creating Aadhaar document record"
        )

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
    # Update Aadhaar
    # ─────────────────────────────────────────────

    else:

        print(
            "\n🔄 Updating existing Aadhaar document"
        )

        aadhaar_document.aadhaar_encrypted = (
            encrypted_aadhaar
        )

        aadhaar_document.aadhaar_last_four = (
            aadhaar_last_four
        )

        aadhaar_document.aadhaar_verified = True

        aadhaar_document.verification_reference = (
            result.get(
                "verification_reference"
            )
        )

    # ─────────────────────────────────────────────
    # Save
    # ─────────────────────────────────────────────

    db.commit()

    db.refresh(aadhaar_document)

    print(
        "\n========== DATABASE UPDATED =========="
    )

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

    print(
        "======================================\n"
    )

    return {
        "verified": True,
        "message": result["message"],
        "user_profile": _build_user_profile_response(
            db,
            user,
        ),
    }


# ═══════════════════════════════════════════════════════════════
# DRIVING LICENCE VERIFICATION
# ═══════════════════════════════════════════════════════════════


@router.post("/driving-licence")
async def verify_driving_licence(
    request: DrivingLicenceVerificationRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Verify Driving Licence for the currently
    authenticated user.
    """

    print(
        "\n========== DRIVING LICENCE VERIFICATION =========="
    )

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
            status_code=404,
            detail="Local user profile not found",
        )

    print(
        "Local User ID:",
        user.id,
    )

    # ─────────────────────────────────────────────
    # Get Provider
    # ─────────────────────────────────────────────

    provider = (
        get_driving_licence_provider()
    )

    result = await provider.verify(
        request.licence_number
    )

    print(
        "\n---------- PROVIDER RESULT ----------"
    )

    print(result)

    # ─────────────────────────────────────────────
    # Stop if Verification Failed
    # ─────────────────────────────────────────────

    if not result["verified"]:

        return {
            "verified": False,
            "message": result["message"],
        }

    # ─────────────────────────────────────────────
    # Encrypt DL
    # ─────────────────────────────────────────────

    encrypted_dl = (
        sensitive_data_encryption.encrypt(
            request.licence_number
        )
    )

    dl_last_four = (
        request.licence_number[-4:]
    )

    print(
        "DL encrypted successfully"
    )

    print(
        "Last four digits:",
        dl_last_four,
    )

    # ─────────────────────────────────────────────
    # Check Existing DL
    # ─────────────────────────────────────────────

    dl_document = (
        db.query(DrivingLicence)
        .filter(
            DrivingLicence.user_id
            == user.id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Create DL
    # ─────────────────────────────────────────────

    if dl_document is None:

        print(
            "🆕 Creating Driving Licence record"
        )

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
    # Update DL
    # ─────────────────────────────────────────────

    else:

        print(
            "🔄 Updating Driving Licence record"
        )

        dl_document.dl_encrypted = (
            encrypted_dl
        )

        dl_document.dl_last_four = (
            dl_last_four
        )

        dl_document.dl_verified = True

        dl_document.verification_reference = (
            result.get(
                "verification_reference"
            )
        )

    # ─────────────────────────────────────────────
    # Save
    # ─────────────────────────────────────────────

    db.commit()

    db.refresh(dl_document)

    print(
        "\n========== DL DATABASE UPDATED =========="
    )

    print(
        "Document ID:",
        dl_document.id,
    )

    print(
        "DL Verified:",
        dl_document.dl_verified,
    )

    print(
        "========================================\n"
    )

    return {
        "verified": True,
        "message": result["message"],
        "user_profile": _build_user_profile_response(
            db,
            user,
        ),
    }


# ═══════════════════════════════════════════════════════════════
# VEHICLE RC VERIFICATION
# ═══════════════════════════════════════════════════════════════


@router.post("/vehicle-rc")
async def verify_vehicle_rc(
    request: VehicleRCVerificationRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Verify and register a vehicle for the authenticated user.

    Flow:

    1. Authenticate the user.
    2. Find local user.
    3. Verify RC through provider.
    4. Normalize registration number.
    5. Find or create Vehicle.
    6. Store vehicle classification and capacity.
    7. Find or create UserVehicle association.
    8. Encrypt RC number.
    9. Create/update VehicleRC.
    10. Return vehicle + updated profile.
    """

    print(
        "\n========== VEHICLE RC VERIFICATION =========="
    )

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
            status_code=404,
            detail="Local user profile not found",
        )

    print(
        "Local User ID:",
        user.id,
    )

    # ─────────────────────────────────────────────
    # Get RC Verification Provider
    # ─────────────────────────────────────────────

    provider = get_vehicle_rc_provider()

    result = await provider.verify(
        request.rc_number
    )

    print(
        "\n---------- PROVIDER RESULT ----------"
    )

    print(result)

    # ─────────────────────────────────────────────
    # Stop if Verification Failed
    # ─────────────────────────────────────────────

    if not result["verified"]:

        print(
            "❌ Vehicle RC verification failed"
        )

        return {
            "verified": False,
            "message": result["message"],
        }

    # ─────────────────────────────────────────────
    # Normalize Registration Number
    # ─────────────────────────────────────────────

    registration_number = (
        request.rc_number
        .strip()
        .upper()
        .replace(" ", "")
    )

    print(
        "Registration Number:",
        registration_number,
    )

    # ─────────────────────────────────────────────
    # Validate Vehicle Classification
    # ─────────────────────────────────────────────

    vehicle_category = (
        request.vehicle_category
        .strip()
        .upper()
    )

    vehicle_subtype = (
        request.vehicle_subtype
        .strip()
        .upper()
    )

    vehicle_type_specified = (
        request.vehicle_type_specified.strip()
        if request.vehicle_type_specified
        else None
    )

    # ─────────────────────────────────────────────
    # Additional Capacity Safety Check
    # ─────────────────────────────────────────────

    if request.seating_capacity < 2:

        raise HTTPException(
            status_code=422,
            detail=(
                "Vehicle seating capacity "
                "must be at least 2."
            ),
        )

    # ─────────────────────────────────────────────
    # Find Existing Vehicle
    # ─────────────────────────────────────────────

    vehicle = (
        db.query(Vehicle)
        .filter(
            Vehicle.registration_number
            == registration_number
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Create Vehicle
    # ─────────────────────────────────────────────

    if vehicle is None:

        print(
            "\n🆕 Creating new Vehicle"
        )

        vehicle = Vehicle(
            registration_number=(
                registration_number
            ),

            vehicle_model=(
                request.vehicle_model.strip()
            ),

            vehicle_color=(
                request.vehicle_color.strip()
                if request.vehicle_color
                else None
            ),

            vehicle_category=(
                vehicle_category
            ),

            vehicle_subtype=(
                vehicle_subtype
            ),

            vehicle_type_specified=(
                vehicle_type_specified
            ),

            seating_capacity=(
                request.seating_capacity
            ),
        )

        db.add(vehicle)

        # Get generated vehicle ID.
        db.flush()

        print(
            "Created Vehicle ID:",
            vehicle.id,
        )

    # ─────────────────────────────────────────────
    # Existing Vehicle
    # ─────────────────────────────────────────────

    else:

        print(
            "\n✅ Existing Vehicle found"
        )

        print(
            "Vehicle ID:",
            vehicle.id,
        )

        # ─────────────────────────────────────────
        # Update verified vehicle information
        # ─────────────────────────────────────────

        vehicle.vehicle_model = (
            request.vehicle_model.strip()
        )

        if request.vehicle_color:
            vehicle.vehicle_color = (
                request.vehicle_color.strip()
            )
        else:
            vehicle.vehicle_color = None

        vehicle.vehicle_category = (
            vehicle_category
        )

        vehicle.vehicle_subtype = (
            vehicle_subtype
        )

        vehicle.vehicle_type_specified = (
            vehicle_type_specified
        )

        vehicle.seating_capacity = (
            request.seating_capacity
        )

    # ─────────────────────────────────────────────
    # Find User ↔ Vehicle Association
    # ─────────────────────────────────────────────

    user_vehicle = (
        db.query(UserVehicle)
        .filter(
            UserVehicle.user_id
            == user.id,

            UserVehicle.vehicle_id
            == vehicle.id,
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Create Association
    # ─────────────────────────────────────────────

    if user_vehicle is None:

        print(
            "\n🆕 Creating UserVehicle association"
        )

        user_vehicle = UserVehicle(
            user_id=user.id,
            vehicle_id=vehicle.id,
            is_active=True,
        )

        db.add(user_vehicle)

    # ─────────────────────────────────────────────
    # Existing Association
    # ─────────────────────────────────────────────

    else:

        print(
            "\n✅ User already associated "
            "with vehicle"
        )

        user_vehicle.is_active = True

    # ─────────────────────────────────────────────
    # Encrypt RC Number
    # ─────────────────────────────────────────────

    encrypted_rc = (
        sensitive_data_encryption.encrypt(
            registration_number
        )
    )

    rc_last_four = (
        registration_number[-4:]
    )

    print(
        "RC encrypted successfully"
    )

    print(
        "Last four digits:",
        rc_last_four,
    )

    # ─────────────────────────────────────────────
    # Find Existing Vehicle RC
    # ─────────────────────────────────────────────

    rc_document = (
        db.query(VehicleRC)
        .filter(
            VehicleRC.vehicle_id
            == vehicle.id
        )
        .first()
    )

    # ─────────────────────────────────────────────
    # Create Vehicle RC
    # ─────────────────────────────────────────────

    if rc_document is None:

        print(
            "\n🆕 Creating Vehicle RC record"
        )

        rc_document = VehicleRC(
            vehicle_id=vehicle.id,

            rc_encrypted=encrypted_rc,

            rc_last_four=rc_last_four,

            rc_verified=True,

            verification_reference=(
                result.get(
                    "verification_reference"
                )
            ),
        )

        db.add(rc_document)

    # ─────────────────────────────────────────────
    # Update Vehicle RC
    # ─────────────────────────────────────────────

    else:

        print(
            "\n🔄 Updating Vehicle RC record"
        )

        rc_document.rc_encrypted = (
            encrypted_rc
        )

        rc_document.rc_last_four = (
            rc_last_four
        )

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

    db.refresh(vehicle)

    db.refresh(user_vehicle)

    db.refresh(rc_document)

    print(
        "\n========== VEHICLE DATABASE UPDATED =========="
    )

    print(
        "Vehicle ID:",
        vehicle.id,
    )

    print(
        "Registration:",
        vehicle.registration_number,
    )

    print(
        "Vehicle Model:",
        vehicle.vehicle_model,
    )

    print(
        "Vehicle Color:",
        vehicle.vehicle_color,
    )

    print(
        "Vehicle Category:",
        vehicle.vehicle_category,
    )

    print(
        "Vehicle Subtype:",
        vehicle.vehicle_subtype,
    )

    print(
        "Specified Vehicle Type:",
        vehicle.vehicle_type_specified,
    )

    print(
        "Seating Capacity:",
        vehicle.seating_capacity,
    )

    print(
        "Maximum LiftOff Seats:",
        vehicle.seating_capacity - 1,
    )

    print(
        "UserVehicle ID:",
        user_vehicle.id,
    )

    print(
        "RC Verified:",
        rc_document.rc_verified,
    )

    print(
        "==============================================\n"
    )

    # ─────────────────────────────────────────────
    # Return Response
    # ─────────────────────────────────────────────

    return {
        "verified": True,

        "message": result["message"],

        "vehicle": {
            "id": vehicle.id,

            "registration_number": (
                vehicle.registration_number
            ),

            "vehicle_model": (
                vehicle.vehicle_model
            ),

            "vehicle_color": (
                vehicle.vehicle_color
            ),

            "vehicle_category": (
                vehicle.vehicle_category
            ),

            "vehicle_subtype": (
                vehicle.vehicle_subtype
            ),

            "vehicle_type_specified": (
                vehicle.vehicle_type_specified
            ),

            "seating_capacity": (
                vehicle.seating_capacity
            ),

            "rc_verified": (
                rc_document.rc_verified
            ),
        },

        "user_profile": (
            _build_user_profile_response(
                db,
                user,
            )
        ),
    }