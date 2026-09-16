from pydantic import BaseModel, Field, model_validator


class AadhaarVerificationRequest(BaseModel):
    """
    Request body received from Flutter
    for Aadhaar verification.
    """

    aadhaar_number: str = Field(
        ...,
        min_length=12,
        max_length=12,
        description="12-digit Aadhaar number",
    )


class DrivingLicenceVerificationRequest(BaseModel):
    """
    Request body received from Flutter
    for Driving Licence verification.
    """

    licence_number: str = Field(
        ...,
        min_length=5,
        max_length=30,
        description="Driving Licence number",
    )


# ═══════════════════════════════════════════════════════════════
# VEHICLE RC VERIFICATION REQUEST
# ═══════════════════════════════════════════════════════════════


class VehicleRCVerificationRequest(BaseModel):
    """
    Request used to verify and register a vehicle.

    The RC number is verified through the configured RC provider.

    Vehicle classification and seating capacity are stored as
    permanent vehicle properties after successful verification.
    """

    # ─── RC / Registration ──────────────────────────────────────

    rc_number: str = Field(
        min_length=4,
        max_length=20,
        description="Vehicle registration / RC number",
    )

    # ─── Basic Vehicle Information ──────────────────────────────

    vehicle_model: str = Field(
        min_length=2,
        max_length=100,
        description="Vehicle make and model",
    )

    vehicle_color: str | None = Field(
        default=None,
        max_length=50,
        description="Vehicle color",
    )

    # ─── Vehicle Classification ────────────────────────────────

    vehicle_category: str = Field(
        min_length=2,
        max_length=50,
        description="Main vehicle category",
    )

    vehicle_subtype: str = Field(
        min_length=2,
        max_length=50,
        description="Vehicle subtype",
    )

    # Used when the host selects OTHER.
    vehicle_type_specified: str | None = Field(
        default=None,
        max_length=100,
        description="Custom vehicle type when OTHER is selected",
    )

    # ─── Capacity ───────────────────────────────────────────────

    seating_capacity: int = Field(
        ge=2,
        le=100,
        description="Total passenger/seating capacity of the vehicle",
    )

    # ─── Validation ─────────────────────────────────────────────

    @model_validator(mode="after")
    def validate_vehicle_type(self):
        """
        Validate the custom vehicle type field.

        If the vehicle subtype is OTHER, the host must provide
        a custom vehicle type.

        For predefined vehicle types, a custom value is not required.
        """

        category = self.vehicle_category.strip().upper()
        subtype = self.vehicle_subtype.strip().upper()

        if (
            category == "OTHER"
            or subtype == "OTHER"
        ):
            if not self.vehicle_type_specified:
                raise ValueError(
                    "Vehicle type must be specified when "
                    "OTHER is selected."
                )

            if not self.vehicle_type_specified.strip():
                raise ValueError(
                    "Vehicle type specification cannot be empty."
                )

        return self