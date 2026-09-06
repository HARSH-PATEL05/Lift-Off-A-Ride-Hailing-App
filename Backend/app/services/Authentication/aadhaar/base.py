from abc import ABC, abstractmethod


class AadhaarVerificationProvider(ABC):
    """
    Base interface for all Aadhaar verification providers.

    Every provider, such as a Sandbox provider or a real
    authorized provider, must implement the verify() method.
    """

    @abstractmethod
    async def verify(self, aadhaar_number: str) -> dict:
        """
        Verify an Aadhaar number.

        Args:
            aadhaar_number: 12-digit Aadhaar number.

        Returns:
            A standardized dictionary containing the
            verification result.
        """

        pass