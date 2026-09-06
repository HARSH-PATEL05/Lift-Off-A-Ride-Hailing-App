from abc import ABC, abstractmethod


class DrivingLicenceVerificationProvider(ABC):
    """
    Base interface for Driving Licence verification providers.

    Any sandbox or real verification provider must implement
    the verify method.
    """

    @abstractmethod
    async def verify(
        self,
        licence_number: str,
    ) -> dict:
        """
        Verify a driving licence number.

        Returns:
            dict containing verification result.
        """

        pass