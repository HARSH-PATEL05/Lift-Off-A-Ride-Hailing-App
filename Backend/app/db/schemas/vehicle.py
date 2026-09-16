from pydantic import BaseModel, Field, model_validator


# ═══════════════════════════════════════════════════════════════
# VEHICLE RESPONSE
# ═══════════════════════════════════════════════════════════════


class VehicleResponse(BaseModel):
    """
    Vehicle information returned to the authenticated user.

    Sensitive RC data is never returned.
    """

    id: int

    registration_number: str

    vehicle_model: str

    vehicle_color: str | None = None

    # ─── Vehicle Classification ─────────────────────────────────

    vehicle_category: str

    vehicle_subtype: str

    # Populated only when the vehicle type is custom/other.
    vehicle_type_specified: str | None = None

    # ─── Capacity ───────────────────────────────────────────────

    # Total verified passenger/seating capacity.
    seating_capacity: int

    # ─── User Vehicle Status ────────────────────────────────────

    is_active: bool

    rc_verified: bool


# ═══════════════════════════════════════════════════════════════
# VEHICLE LIST RESPONSE
# ═══════════════════════════════════════════════════════════════


class VehicleListResponse(BaseModel):
    """
    Response containing all vehicles associated
    with the authenticated user.
    """

    vehicles: list[VehicleResponse]


# ═══════════════════════════════════════════════════════════════
# VEHICLE UPDATE REQUEST
# ═══════════════════════════════════════════════════════════════


class VehicleUpdateRequest(BaseModel):
    """
    Update vehicle metadata.

    Registration number, classification and seating capacity
    cannot be changed through this endpoint because they belong
    to the verified vehicle identity.

    If any of these permanent properties need to change,
    the vehicle should go through the appropriate verification
    process again.
    """

    vehicle_model: str | None = Field(
        default=None,
        min_length=2,
        max_length=100,
        description="Vehicle make and model",
    )

    vehicle_color: str | None = Field(
        default=None,
        max_length=50,
        description="Vehicle color",
    )


# ═══════════════════════════════════════════════════════════════
# VEHICLE STATUS UPDATE
# ═══════════════════════════════════════════════════════════════


class VehicleStatusUpdateRequest(BaseModel):
    """
    Activate or deactivate a user's vehicle association.
    """

    is_active: bool