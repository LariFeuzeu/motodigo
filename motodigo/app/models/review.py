from sqlalchemy import Column, BigInteger, SmallInteger, Text, DateTime, ForeignKey, CheckConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base


class Review(Base):
    __tablename__ = "reviews"

    id = Column(BigInteger, primary_key=True, index=True)
    trip_id = Column(BigInteger, ForeignKey("trips.id", ondelete="CASCADE"), index=True)
    # Note : Nécessite des 'foreign_keys' pour distinguer l'émetteur du récepteur dans les relations User.
    from_user = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    to_user = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    rating = Column(SmallInteger)  # SMALLINT en SQL
    comment = Column(Text)
    created_at = Column(DateTime(timezone=True), default=func.now())

    __table_args__ = (
        CheckConstraint((rating >= 1) & (rating <= 5), name='rating_range_check'),

    )

    # Relations ORM
    trips = relationship("Trip", back_populates="reviews")
    reviewer = relationship("User", foreign_keys=[from_user], back_populates="reviews_given")
    reviewee = relationship("User", foreign_keys=[to_user], back_populates="reviews_received")