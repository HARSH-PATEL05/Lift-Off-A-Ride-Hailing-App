from app.services.Authentication.vehicle_rc.base import (
    VehicleRCVerificationProvider,
)

from app.services.Authentication.vehicle_rc.rc_sandbox import (
    SandboxVehicleRCProvider,
)


def get_vehicle_rc_provider() -> VehicleRCVerificationProvider:
    """
    Return the currently configured Vehicle RC
    verification provider.

    Currently:
        SandboxVehicleRCProvider

    Later:
        RealVehicleRCProvider
    """

    return SandboxVehicleRCProvider()