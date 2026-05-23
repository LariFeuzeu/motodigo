from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class ReviewCreate(BaseModel):
    trip_id: int
    to_user: int
    rating: int = Field(..., ge=1, le=5, description="La note doit être comprise entre 1 et 5")
    comment: Optional[str] = None


class ReviewResponse(BaseModel):
    id: int
    trip_id: int
    from_user: int
    to_user: int
    rating: int
    comment: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True  # Permet de mapper directement l'objet SQLAlchemy
