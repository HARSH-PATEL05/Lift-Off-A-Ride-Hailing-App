from cryptography.fernet import Fernet, InvalidToken

from app.core.config import settings


class SensitiveDataEncryption:
    """
    Handles encryption and decryption of sensitive user data.

    Used for:
    - Aadhaar numbers
    - Driving licence numbers
    - RC numbers
    """

    def __init__(self):
        encryption_key = settings.DATA_ENCRYPTION_KEY

        if not encryption_key:
            raise ValueError(
                "DATA_ENCRYPTION_KEY is missing from environment variables"
            )

        self.fernet = Fernet(encryption_key.encode())

    def encrypt(self, value: str) -> str:
        """
        Encrypt sensitive data.

        Returns encrypted string that can be safely stored
        in PostgreSQL.
        """

        if not value:
            raise ValueError("Cannot encrypt an empty value")

        encrypted_value = self.fernet.encrypt(
            value.encode()
        )

        return encrypted_value.decode()

    def decrypt(self, encrypted_value: str) -> str:
        """
        Decrypt previously encrypted sensitive data.
        """

        if not encrypted_value:
            raise ValueError("Cannot decrypt an empty value")

        try:
            decrypted_value = self.fernet.decrypt(
                encrypted_value.encode()
            )

            return decrypted_value.decode()

        except InvalidToken:
            raise ValueError(
                "Unable to decrypt data. Invalid encryption key or corrupted data."
            )


# Singleton instance used throughout the application.
sensitive_data_encryption = SensitiveDataEncryption()