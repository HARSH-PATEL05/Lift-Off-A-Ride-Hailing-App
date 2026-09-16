from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies.auth import get_current_user
from app.db.database import get_db

from app.db.models.user import User
from app.db.models.vehicle import Vehicle
from app.db.models.user_vehicle import UserVehicle

from app.db.schemas.vehicle import (
    VehicleResponse,
    VehicleListResponse,
    VehicleUpdateRequest,
    VehicleStatusUpdateRequest,
)


router = APIRouter(
    prefix="/vehicles",
    tags=["Vehicles"],
)


# ═══════════════════════════════════════════════════════════════
# HELPER — FIND LOCAL USER
# ═══════════════════════════════════════════════════════════════


def _get_local_user(
    db: Session,
    current_user,
) -> User:
    """
    Find the local PostgreSQL user corresponding
    to the authenticated Supabase user.
    """

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
                "Local user profile not found. "
                "Please sync your account first."
            ),
        )

    return user


# ═══════════════════════════════════════════════════════════════
# HELPER — BUILD VEHICLE RESPONSE
# ═══════════════════════════════════════════════════════════════


def _build_vehicle_response(
    vehicle: Vehicle,
    user_vehicle: UserVehicle,
) -> dict:
    """
    Build a safe vehicle response.

    Sensitive RC data is NEVER returned.

    The response contains the permanent vehicle information
    required by the frontend, including classification and
    seating capacity.
    """

    rc_verified = False

    if (
        vehicle.vehicle_rc is not None
        and vehicle.vehicle_rc.rc_verified
    ):
        rc_verified = True

    return {
        # ─────────────────────────────────────────
        # Vehicle Identity
        # ─────────────────────────────────────────

        "id": vehicle.id,

        "registration_number": (
            vehicle.registration_number
        ),

        # ─────────────────────────────────────────
        # Basic Information
        # ─────────────────────────────────────────

        "vehicle_model": (
            vehicle.vehicle_model
        ),

        "vehicle_color": (
            vehicle.vehicle_color
        ),

        # ─────────────────────────────────────────
        # Vehicle Classification
        # ─────────────────────────────────────────

        "vehicle_category": (
            vehicle.vehicle_category
        ),

        "vehicle_subtype": (
            vehicle.vehicle_subtype
        ),

        "vehicle_type_specified": (
            vehicle.vehicle_type_specified
        ),

        # ─────────────────────────────────────────
        # Capacity
        # ─────────────────────────────────────────

        "seating_capacity": (
            vehicle.seating_capacity
        ),

        # ─────────────────────────────────────────
        # User Vehicle Status
        # ─────────────────────────────────────────

        "is_active": (
            user_vehicle.is_active
        ),

        "rc_verified": rc_verified,
    }


# ═══════════════════════════════════════════════════════════════
# GET ALL USER VEHICLES
# ═══════════════════════════════════════════════════════════════


@router.get(
    "",
    response_model=VehicleListResponse,
)
async def get_my_vehicles(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Return all vehicles associated with
    the authenticated user.

    Vehicles are obtained through the
    UserVehicle association table.
    """

    print(
        "\n========== GET USER VEHICLES =========="
    )

    # ─────────────────────────────────────────────
    # Find Local User
    # ─────────────────────────────────────────────

    user = _get_local_user(
        db,
        current_user,
    )

    print(
        "Local User ID:",
        user.id,
    )

    # ─────────────────────────────────────────────
    # Get User Vehicles
    # ─────────────────────────────────────────────

    user_vehicles = (
        db.query(UserVehicle)
        .join(
            Vehicle,
            UserVehicle.vehicle_id
            == Vehicle.id,
        )
        .filter(
            UserVehicle.user_id
            == user.id
        )
        .order_by(
            UserVehicle.created_at.desc()
        )
        .all()
    )

    print(
        "Vehicle Count:",
        len(user_vehicles),
    )

    # ─────────────────────────────────────────────
    # Build Response
    # ─────────────────────────────────────────────

    vehicles = [
        _build_vehicle_response(
            user_vehicle.vehicle,
            user_vehicle,
        )
        for user_vehicle in user_vehicles
    ]

    print(
        "========================================\n"
    )

    return {
        "vehicles": vehicles,
    }


# ═══════════════════════════════════════════════════════════════
# GET SINGLE VEHICLE
# ═══════════════════════════════════════════════════════════════


@router.get(
    "/{vehicle_id}",
    response_model=VehicleResponse,
)
async def get_my_vehicle(
    vehicle_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Return one vehicle belonging to
    the authenticated user.
    """

    print(
        "\n========== GET VEHICLE =========="
    )

    user = _get_local_user(
        db,
        current_user,
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
            == vehicle_id,
        )
        .first()
    )

    if user_vehicle is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found for this user.",
        )

    vehicle = user_vehicle.vehicle

    print(
        "Vehicle ID:",
        vehicle.id,
    )

    print(
        "Registration:",
        vehicle.registration_number,
    )

    print(
        "=================================\n"
    )

    return _build_vehicle_response(
        vehicle,
        user_vehicle,
    )


# ═══════════════════════════════════════════════════════════════
# UPDATE VEHICLE METADATA
# ═══════════════════════════════════════════════════════════════


@router.patch(
    "/{vehicle_id}",
    response_model=VehicleResponse,
)
async def update_my_vehicle(
    vehicle_id: int,
    request: VehicleUpdateRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Update vehicle metadata.

    Allowed:
        - vehicle_model
        - vehicle_color

    Registration number, classification and seating capacity
    cannot be changed through this endpoint.

    These properties belong to the verified vehicle identity.
    """

    print(
        "\n========== UPDATE VEHICLE =========="
    )

    user = _get_local_user(
        db,
        current_user,
    )

    # ─────────────────────────────────────────────
    # Find User Vehicle
    # ─────────────────────────────────────────────

    user_vehicle = (
        db.query(UserVehicle)
        .filter(
            UserVehicle.user_id
            == user.id,

            UserVehicle.vehicle_id
            == vehicle_id,
        )
        .first()
    )

    if user_vehicle is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found for this user.",
        )

    vehicle = user_vehicle.vehicle

    # ─────────────────────────────────────────────
    # Update Model
    # ─────────────────────────────────────────────

    if request.vehicle_model is not None:

        clean_model = (
            request.vehicle_model.strip()
        )

        if len(clean_model) < 2:
            raise HTTPException(
                status_code=(
                    status.HTTP_422_UNPROCESSABLE_ENTITY
                ),
                detail=(
                    "Vehicle model must contain "
                    "at least 2 characters."
                ),
            )

        vehicle.vehicle_model = clean_model

    # ─────────────────────────────────────────────
    # Update Color
    # ─────────────────────────────────────────────

    if "vehicle_color" in request.model_fields_set:

        if request.vehicle_color is None:

            vehicle.vehicle_color = None

        else:

            clean_color = (
                request.vehicle_color.strip()
            )

            vehicle.vehicle_color = (
                clean_color
                if clean_color
                else None
            )

    # ─────────────────────────────────────────────
    # Save
    # ─────────────────────────────────────────────

    db.commit()

    db.refresh(vehicle)
    db.refresh(user_vehicle)

    print(
        "Vehicle updated successfully"
    )

    print(
        "Vehicle ID:",
        vehicle.id,
    )

    print(
        "====================================\n"
    )

    return _build_vehicle_response(
        vehicle,
        user_vehicle,
    )


# ═══════════════════════════════════════════════════════════════
# ACTIVATE / DEACTIVATE VEHICLE
# ═══════════════════════════════════════════════════════════════


@router.patch(
    "/{vehicle_id}/status",
    response_model=VehicleResponse,
)
async def update_vehicle_status(
    vehicle_id: int,
    request: VehicleStatusUpdateRequest,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Activate or deactivate a vehicle for
    the authenticated user.

    This changes UserVehicle.is_active,
    not the Vehicle itself.
    """

    print(
        "\n========== UPDATE VEHICLE STATUS =========="
    )

    user = _get_local_user(
        db,
        current_user,
    )

    # ─────────────────────────────────────────────
    # Find User Vehicle
    # ─────────────────────────────────────────────

    user_vehicle = (
        db.query(UserVehicle)
        .filter(
            UserVehicle.user_id
            == user.id,

            UserVehicle.vehicle_id
            == vehicle_id,
        )
        .first()
    )

    if user_vehicle is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found for this user.",
        )

    # ─────────────────────────────────────────────
    # Update Status
    # ─────────────────────────────────────────────

    user_vehicle.is_active = (
        request.is_active
    )

    db.commit()

    db.refresh(user_vehicle)

    vehicle = user_vehicle.vehicle

    print(
        "Vehicle ID:",
        vehicle.id,
    )

    print(
        "Active:",
        user_vehicle.is_active,
    )

    print(
        "============================================\n"
    )

    return _build_vehicle_response(
        vehicle,
        user_vehicle,
    )