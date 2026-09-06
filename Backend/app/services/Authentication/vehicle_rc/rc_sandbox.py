from app.services.Authentication.vehicle_rc.base import (
    VehicleRCVerificationProvider,
)


class SandboxVehicleRCProvider(
    VehicleRCVerificationProvider
):
    """
    Sandbox implementation for Vehicle RC verification.

    This is temporary and can later be replaced with
    a real Vehicle RC verification API provider.
    """

    async def verify(
        self,
        rc_number: str,
    ) -> dict:

        print("\n========== RC SANDBOX VERIFICATION ==========")

        print("RC Number Received")

        # Basic sandbox validation
        if not rc_number:
            return {
                "verified": False,
                "message": "Vehicle RC number is required",
                "verification_reference": None,
            }

        # ─────────────────────────────────────────
        # SANDBOX LOGIC
        # ─────────────────────────────────────────
        #
        # For now, any non-empty RC number
        # will be considered verified.
        #
        # Later replace this provider with an
        # authorized RC verification API.
        #
        # ─────────────────────────────────────────

        print("RC verification successful")

        return {
            "verified": True,
            "message": "Vehicle RC verified successfully",
            "verification_reference": (
                f"RC-SANDBOX-{rc_number[-4:]}"
            ),
        }