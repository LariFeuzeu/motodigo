from sqlalchemy import Column, Integer, Text, BigInteger, Numeric, DateTime, ForeignKey, String, CheckConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base


class Trip(Base):
    __tablename__ = "trips"

    id = Column(BigInteger, primary_key=True, index=True)
    driver_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    vehicle_id = Column(BigInteger, ForeignKey("vehicles.id", ondelete="CASCADE"), nullable=False)
    country_code = Column(String(2), nullable=False, index=True)
    origin_city = Column(Text, nullable=False)
    destination_city = Column(Text, nullable=False)
    baggage_size = Column(String(20), default="Moyen")
    baggage_details = Column(Text, nullable=True)
    # Coordonnées (NUMERIC(9,6) en SQL)
    origin_lat = Column(Numeric(9, 6))
    origin_lng = Column(Numeric(9, 6))
    origin_label = Column(Text)
    destination_lat = Column(Numeric(9, 6))
    destination_lng = Column(Numeric(9, 6))
    destination_label = Column(Text)
    waypoints = Column(JSONB, server_default='[]')
    departure_at = Column(DateTime(timezone=True), nullable=False)
    price_per_seat = Column(Numeric(10, 2), nullable=False)
    seats_total = Column(Integer, nullable=False)
    seats_available = Column(Integer, nullable=False)

    status = Column(String(20), default='published')
    created_at = Column(DateTime(timezone=True), default=func.now())

    __table_args__ = (
        CheckConstraint(status.in_(['published', 'started', 'completed', 'cancelled', 'full']),
                        name='trips_status_check'),
    )

    # Relations ORM
    driver = relationship("User", back_populates="trips_as_driver")
    vehicle = relationship("Vehicle", back_populates="trips")
    bookings = relationship("Booking", back_populates="trip", cascade="all, delete-orphan")
    reviews = relationship("Review", back_populates="trips")
    messages = relationship("Message", back_populates="trip")
