# app/crud/crud_booking.py
from sqlalchemy.orm import Session
from app.models.booking import Booking
from app.models.transaction import Transaction


def create_booking_record(db: Session, obj_in_data: dict) -> Booking:
    db_obj = Booking(**obj_in_data)
    db.add(db_obj)
    db.flush()
    return db_obj


def get_booking_by_id(db: Session, booking_id: int) -> Booking:
    return db.query(Booking).filter(Booking.id == booking_id).first()


def create_transaction_record(db: Session, trans_data: dict):
    db_obj = Transaction(**trans_data)
    db.add(db_obj)
    return db_obj
