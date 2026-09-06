from app.services.Authentication.aadhaar.base import AadhaarVerificationProvider


class SandboxAadhaarProvider(AadhaarVerificationProvider):
    """
    Sandbox implementation for Aadhaar verification.

    This provider is used during development and testing.
    Later, it can be replaced with an authorized real provider
    without changing the API route.
    """

    async def verify(self, aadhaar_number: str) -> dict:
        """
        Simulate Aadhaar verification.
        """

        print("\n========== AADHAAR SANDBOX VERIFICATION ==========")

        print("Aadhaar received:", aadhaar_number)

        # Basic validation
        if not aadhaar_number.isdigit():
            return {
                "verified": False,
                "message": "Aadhaar number must contain only digits",
                "verification_reference": None,
            }

        if len(aadhaar_number) != 12:
            return {
                "verified": False,
                "message": "Aadhaar number must contain exactly 12 digits",
                "verification_reference": None,
            }

        # ─────────────────────────────────────────────
        # Sandbox verification
        # ─────────────────────────────────────────────

        # Currently, every valid 12-digit Aadhaar number
        # passes sandbox verification.
        #
        # Later, this section will call the actual sandbox API.

        verification_reference = (
            f"SANDBOX-AADHAAR-{aadhaar_number[-4:]}"
        )

        print("Verification result: SUCCESS")
        print("Reference:", verification_reference)

        print("=================================================\n")

        return {
            "verified": True,
            "message": "Aadhaar verified successfully",
            "verification_reference": verification_reference,
        }