from pydantic import BaseModel, Field


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


class VehicleRCVerificationRequest(BaseModel):
    """
    Request body received from Flutter
    for Vehicle RC verification.
    """

    rc_number: str = Field(
        ...,
        min_length=5,
        max_length=20,
        description="Vehicle registration / RC number",
    )