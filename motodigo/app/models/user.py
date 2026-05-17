from sqlalchemy import Column, Integer, String, Text, DateTime, BigInteger, CheckConstraint, Enum
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from app.shemas import UserRole
from app.shemas import DriverRequestStatus


class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger, primary_key=True, index=True)
    full_name = Column(Text, nullable=False)
    email = Column(Text, unique=True, index=True)
    phone = Column(Text, nullable=False)
    role = Column(String(10), nullable=False)
    created_at = Column(DateTime(timezone=True), default=func.now())
    password_hash = Column(Text, nullable=False)
    country_code = Column(String(2), index=True)
    profile_photo_url = Column(Text, nullable=True)
    firebase_uid = Column(String(128), unique=True, index=True, nullable=False)
    # Indique le rôle désiré, en attente de validation
    requested_role = Column(Enum(UserRole), nullable=True)
    driver_request_status = Column(Enum(DriverRequestStatus), default=DriverRequestStatus.en_attente)
    __table_args__ = (
        CheckConstraint("role IN ('passenger', 'driver')", name='role_check'),
    )

    # Relations ORM : Permet d'accéder aux données liées (ex: user.vehicules)
    vehicules = relationship("Vehicle", back_populates="driver", cascade="all, delete-orphan")
    trips_as_driver = relationship("Trip", back_populates="driver", cascade="all, delete-orphan")
    bookings_as_passenger = relationship("Booking", back_populates="passenger")
    reviews_given = relationship("Review", foreign_keys="[Review.from_user]", back_populates="reviewer")
    reviews_received = relationship("Review", foreign_keys="[Review.to_user]", back_populates="reviewee")
