from pydantic import BaseModel, Field
from typing import Optional


# shema de creation

class VehiculeBase(BaseModel):
    plate: str = Field(..., max_length=15)
    model_name: Optional[str] = None
    # make: Optional[str] = None
    # year: Optional[int] = None
    color: Optional[str] = None
    seats: int = Field(..., gt=1, le=8)


class VehiculeCreate(VehiculeBase):
    pass


class VehiculeUpdate(VehiculeBase):
    pass


class VehiculeShema(VehiculeBase):
    id: int
    driver_id: int
    is_active: bool
    registration_card_url: Optional[str] = None
    technical_inspection_url: Optional[str] = None
    vehicle_photo_url: Optional[str] = None

    class Config:
        from_attributes = True
