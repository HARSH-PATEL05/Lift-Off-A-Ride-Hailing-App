from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class Aadhaar(Base):
    __tablename__ = "aadhaar_documents"

    # ─── Primary Key ───

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
    )

    # ─── User Relationship ───

    # Links Aadhaar document to the local user table
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        unique=True,
        nullable=False,
        index=True,
    )

    # Relationship with User model
    user = relationship(
        "User",
        backref="aadhaar_document",
    )

    # ─── Aadhaar Information ───

    # Encrypted Aadhaar number
    aadhaar_encrypted: Mapped[str] = mapped_column(
        String,
        nullable=False,
    )

    # Last 4 digits for safe display
    # Example: XXXX XXXX 1234
    aadhaar_last_four: Mapped[str] = mapped_column(
        String(4),
        nullable=False,
    )

    # ─── Aadhaar Verification ───

    aadhaar_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    # Optional transaction/reference ID returned
    # by the Aadhaar verification provider
    verification_reference: Mapped[str | None] = mapped_column(
        String,
        nullable=True,
    )

    # ─── Timestamps ───

    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )