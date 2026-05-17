from sqlalchemy import Column, Integer, Text, BigInteger, Boolean, ForeignKey, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base


class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(BigInteger, primary_key=True, index=True)
    # Clé étrangère avec CASCADE DELETE, correspond au schéma SQL
    driver_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    make = Column(Text)
    model_name = Column(Text)
    #  year = Column(Integer)
    plate = Column(Text, nullable=False, unique=True)  # Ajout d'une contrainte UNIQUE
    seats = Column(Integer, nullable=False)
    color = Column(Text)
    registration_card_url = Column(Text, nullable=True)  # URL de la carte grise
    technical_inspection_url = Column(Text, nullable=True) # URL de la visite technique
    vehicle_photo_url = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=func.now())

    # Relations
    driver = relationship("User", back_populates="vehicules")
    trips = relationship("Trip", back_populates="vehicle")
