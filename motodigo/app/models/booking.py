from sqlalchemy import Column, Integer, BigInteger, Numeric, DateTime, ForeignKey, String, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(BigInteger, primary_key=True, index=True)
    trip_id = Column(BigInteger, ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True)
    passenger_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    seats_booked = Column(Integer, nullable=False)
    amount_total = Column(Numeric(12, 2), nullable=False)

    status = Column(String(20), default='pending')
    created_at = Column(DateTime(timezone=True), default=func.now())

    __table_args__ = (
        CheckConstraint(seats_booked > 0, name='seats_booked_positive'),
        # On utilise la variable status au lieu d'un string SQL
        CheckConstraint(status.in_(['pending', 'confirmed', 'cancelled', 'completed', 'full']),
                        name='booking_status_check'),
    )

    # Relations ORM
    trip = relationship("Trip", back_populates="bookings")
    passenger = relationship("User", back_populates="bookings_as_passenger")
    transactions = relationship("Transaction", back_populates="booking", cascade="all, delete-orphan")
