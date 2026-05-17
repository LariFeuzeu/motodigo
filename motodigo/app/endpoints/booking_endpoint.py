from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from decimal import Decimal
from datetime import datetime, timedelta
from app.database import get_db
from app.models.trip import Trip
from app.models.booking import Booking
from app.models.transaction import Transaction
from app.core.security import get_current_user
from app.shemas.booking_schema import BookingRead, BookingCreate
from app.services.booking_services import BookingService

router = APIRouter()


@router.post("/", response_model=BookingRead)
async def create_booking(
        booking_in: BookingCreate,
        db: Session = Depends(get_db),
        current_user=Depends(get_current_user)
):
    # On délègue TOUT au service
    return BookingService.process_booking(db, booking_in, current_user.id)


@router.delete("/{booking_id}/cancel")
async def cancel_booking(
        booking_id: int,
        db: Session = Depends(get_db),
        current_user=Depends(get_current_user)
):
    return BookingService.process_cancellation(db, booking_id, current_user.id)


@router.get("/myBookings", response_model=List[BookingRead])
async def get_user_booking(db: Session = Depends(get_db), current_user=Depends(get_current_user)):\

    return db.query(Booking) \
        .options(joinedload(Booking.trip)) \
        .filter(Booking.passenger_id == current_user.id) \
        .all()
