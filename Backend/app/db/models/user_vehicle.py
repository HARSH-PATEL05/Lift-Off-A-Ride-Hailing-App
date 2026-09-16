from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class UserVehicle(Base):
    __tablename__ = "user_vehicles"

    id: Mapped[int] = mapped_column(
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    vehicle_id: Mapped[int] = mapped_column(
        ForeignKey("vehicles.id"),
        nullable=False,
        index=True,
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

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

    user = relationship(
        "User",
        back_populates="user_vehicles",
    )

    vehicle = relationship(
        "Vehicle",
        back_populates="user_vehicles",
    )