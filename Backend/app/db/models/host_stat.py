from datetime import datetime
from sqlalchemy import DateTime, Float, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.database import Base


class HostStat(Base):
    """
    Stores host performance metrics (Fuel Recovered, Shared Commutes, CO2 Saved).
    """

    __tablename__ = "host_stats"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
        autoincrement=True,
    )

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id"),
        unique=True,
        nullable=False,
        index=True,
    )

    fuel_recovered_inr: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )

    shared_commutes_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    co2_saved_kg: Mapped[float] = mapped_column(
        Float,
        default=0.0,
        nullable=False,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )

    user = relationship("User", backref="host_stat")
