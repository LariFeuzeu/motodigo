from pydantic import BaseModel
from datetime import datetime
from decimal import Decimal
from typing import Optional

from app.shemas.trips_schema import TripRead


class BookingCreate(BaseModel):
    trip_id: int
    seats_booked: int = 1
    payment_method: str

    # Donnee envoie par API


class BookingRead(BaseModel):
    id: int
    trip_id: int
    passenger_id: int
    seats_booked: int
    amount_total: Decimal
    status: str
    created_at: datetime
    trip: Optional[TripRead] = None

    class Config:
        from_attributes = True  # Indispensable pour que Pydantic lise les objets SQLAlchemy