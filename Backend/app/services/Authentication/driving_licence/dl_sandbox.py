from app.services.Authentication.driving_licence.base import (
    DrivingLicenceVerificationProvider,
)


class SandboxDrivingLicenceProvider(
    DrivingLicenceVerificationProvider
):
    """
    Sandbox implementation for Driving Licence verification.

    This is temporary and can later be replaced with
    a real Driving Licence verification API provider.
    """

    async def verify(
        self,
        licence_number: str,
    ) -> dict:

        print("\n========== DL SANDBOX VERIFICATION ==========")

        print("Licence Number Received")

        # Basic sandbox validation
        if not licence_number:
            return {
                "verified": False,
                "message": "Driving licence number is required",
                "verification_reference": None,
            }

        # ─────────────────────────────────────────
        # SANDBOX LOGIC
        # ─────────────────────────────────────────
        #
        # For now, any non-empty licence number
        # will be considered verified.
        #
        # Later, replace this logic with:
        #
        # RealDrivingLicenceProvider
        #        ↓
        # Government / authorized verification API
        #
        # ─────────────────────────────────────────

        print("DL verification successful")

        return {
            "verified": True,
            "message": "Driving licence verified successfully",
            "verification_reference": (
                f"DL-SANDBOX-{licence_number[-4:]}"
            ),
        }