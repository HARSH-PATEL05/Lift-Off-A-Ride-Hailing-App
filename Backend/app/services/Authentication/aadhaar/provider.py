from app.services.Authentication.aadhaar.base import AadhaarVerificationProvider
from app.services.Authentication.aadhaar.aadhar_sandbox import SandboxAadhaarProvider


def get_aadhaar_provider() -> AadhaarVerificationProvider:
    """
    Return the currently configured Aadhaar
    verification provider.

    Currently:
        SandboxAadhaarProvider

    Later:
        RealAadhaarProvider
    """

    return SandboxAadhaarProvider()