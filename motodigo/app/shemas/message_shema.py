from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional


class MessageCreate(BaseModel):
    content: str
    trip_id: int  # Doit correspondre au nom dans le modèle SQL
    receiver_id: int  # Obligatoire car nullable=False en base de données


class MessageRead(BaseModel):
    id: int
    content: str
    trip_id: int
    sender_id: int
    receiver_id: int
    is_read: bool
    created_at: datetime  # Attention tu avais écrit "crated_at" (faute de frappe)

    model_config = ConfigDict(from_attributes=True)
