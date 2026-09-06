from app.services.Authentication.driving_licence.base import (
    DrivingLicenceVerificationProvider,
)

from app.services.Authentication.driving_licence.dl_sandbox import (
    SandboxDrivingLicenceProvider,
)


def get_driving_licence_provider() -> DrivingLicenceVerificationProvider:
    """
    Return the currently configured Driving Licence
    verification provider.

    Currently:
        SandboxDrivingLicenceProvider

    Later:
        RealDrivingLicenceProvider
    """

    return SandboxDrivingLicenceProvider()