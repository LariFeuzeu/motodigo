from pydantic import BaseModel, Field, ConfigDict, field_validator
from datetime import datetime
from decimal import Decimal
from typing import Optional, List, Any, Dict


# Ce que le Flutter envoie (TripCreate)
class TripBase(BaseModel):
    vehicle_id: int
    origin_city: str
    destination_city: str
    origin_label: str
    destination_label: str
    origin_lat: float
    origin_lng: float
    baggage_size: str
    baggage_details: Optional[str] = None
    destination_lat: float
    destination_lng: float
    departure_at: datetime
    price_per_seat: Decimal
    seats_total: int
    country_code: str = Field(..., min_length=2, max_length=2, description="Ex: TD, GA, CM")
    waypoints: Optional[List[Dict[str, Any]]] = []
    driver_name: Optional[str] = None


class TripCreate(TripBase):
    pass


# Ce que l'API renvoie au Flutter (TripRead)
class TripRead(TripBase):
    id: int
    driver_id: int
    seats_available: int
    country_code: str
    status: str
    created_at: datetime

    # Ces champs vont recevoir les données des validateurs
    driver_name: Optional[str] = None
    vehicle_model: Optional[str] = None
    # indispensable pour que pydantic puisse lire les objets SQLAlchemy
    model_config = ConfigDict(from_attributes=True)

    #  hasattr() Il sert à vérifier si un objet possède une propriété (une variable ou une relation) avant d'essayer de l'utiliser.
    # fait passer la donnée dans cette fonction pour la transformer.
    @field_validator("driver_name", mode="before")
    # permet à la fonction de travailler directement sur la Classe elle-même.
    @classmethod
    def get_driver_name(cls, v: Any, info: Any) -> str:
        # si trip_obj a une relation driver , on prends le nom
        if hasattr(v, "driver") and v.driver:
            return v.driver.full_name
        return v or "Chauffeur"

    @field_validator("vehicle_model", mode="before")
    @classmethod
    def get_vehicle_model(cls, v: Any) -> str:
        if hasattr(v, "vehicle") and v.vehicle:
            v_obj = v.vehicle
            return f"{v_obj.make or ''} {v_obj.model_name or ''}".strip()
        return v or "vehicle"
