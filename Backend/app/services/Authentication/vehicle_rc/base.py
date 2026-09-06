from abc import ABC, abstractmethod


class VehicleRCVerificationProvider(ABC):
    """
    Base interface for Vehicle RC verification providers.

    Any sandbox or real RC verification provider
    must implement the verify method.
    """

    @abstractmethod
    async def verify(
        self,
        rc_number: str,
    ) -> dict:
        """
        Verify a vehicle registration / RC number.

        Returns:
            dict containing verification result.
        """

        pass