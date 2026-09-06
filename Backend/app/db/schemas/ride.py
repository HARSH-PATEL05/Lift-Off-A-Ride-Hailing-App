from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# ─── Request: Host creates a ride ────────────────────────────────────────────

class RideCreateRequest(BaseModel):
    """
    Payload the frontend sends when a host publishes a commute route.

    Location coordinates are optional for now — the frontend currently uses
    hardcoded MockData values (Connaught Place → DLF Cyber City).
    Once search bars are integrated with Google Maps, lat/lng will always be present.
    """

    # Origin
    origin_name: str = Field(..., example="Connaught Place, New Delhi")
    origin_lat: Optional[float] = Field(None, example=28.6315)
    origin_lng: Optional[float] = Field(None, example=77.2167)

    # Destination
    destination_name: str = Field(..., example="DLF Cyber City, Gurgaon")
    destination_lat: Optional[float] = Field(None, example=28.4595)
    destination_lng: Optional[float] = Field(None, example=77.0266)

    # Schedule
    departure_time: datetime = Field(..., example="2026-09-07T18:00:00")

    # Seats & Fare
    available_seats: int = Field(..., ge=1, le=6, example=3)
    fare_per_seat: float = Field(..., ge=0, example=140.0)

    # Vehicle (optional for MVP)
    vehicle_model: Optional[str] = Field(None, example="Honda City")
    vehicle_number: Optional[str] = Field(None, example="DL 3C XX 1234")

    # Policies
    is_women_only: bool = Field(False)
    democratic_consent: bool = Field(True)


# ─── Response: what the API returns ──────────────────────────────────────────

class RideResponse(BaseModel):
    """Returned after creating or fetching a ride."""

    ride_id: int
    host_id: str
    host_name: Optional[str]   # resolved from users table
    host_avatar: Optional[str]

    origin_name: str
    origin_lat: Optional[float]
    origin_lng: Optional[float]

    destination_name: str
    destination_lat: Optional[float]
    destination_lng: Optional[float]

    departure_time: datetime
    available_seats: int
    fare_per_seat: float

    vehicle_model: Optional[str]
    vehicle_number: Optional[str]

    is_women_only: bool
    democratic_consent: bool
    status: str

    created_at: datetime

    class Config:
        from_attributes = True


# ─── Response: cancel action ─────────────────────────────────────────────────

class RideCancelResponse(BaseModel):
    ride_id: int
    status: str
    message: str
