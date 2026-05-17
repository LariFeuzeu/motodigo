from sqlalchemy import Column, BigInteger, Numeric, Text, DateTime, ForeignKey, String, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(BigInteger, primary_key=True, index=True)
    booking_id = Column(BigInteger, ForeignKey("bookings.id", ondelete="CASCADE"), index=True)
    
    provider_transaction_id = Column(Text)
    amount = Column(Numeric(12, 2), nullable=False)
    platform_fee = Column(Numeric(12, 2), nullable=False)
    driver_amount = Column(Numeric(12, 2), nullable=False)
    
    status = Column(String(20))
    created_at = Column(DateTime(timezone=True), default=func.now())
    
    __table_args__ = (
        CheckConstraint(status.in_(['held', 'released', 'refunded', 'failed']), name='transaction_status_check'),
    )

    # Relation ORM
    booking = relationship("Booking", back_populates="transactions")