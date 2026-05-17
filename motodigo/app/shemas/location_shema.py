from pydantic import BaseModel, Field, validator
from typing import List, Optional

# Requête de Flutter vers FastAPI
class LocationQuery(BaseModel):
    query: str = Field(..., min_length=2, description="Chaîne de recherche de l'utilisateur")
    # Cibler le pays (Ex: 'CM', 'FR', 'CI')
    country_code: str = Field(..., min_length=2, max_length=2, description="Code pays ISO alpha-2")

# Schéma de réponse FastAPI vers Flutter
class LocationSuggestion(BaseModel):
    place_id: str = Field(..., description="ID unique de la localisation")
    display_name: str = Field(..., description="Nom complet formaté pour l'UI")
    latitude: float
    longitude: float
    # Optionnel car Photon ne le renvoie pas toujours de manière fiable
    country_code: Optional[str] = Field(None, description="Code pays de la suggestion")

    class Config:
        # Permet de transformer facilement les objets SQLAlchemy en Schémas si besoin
        from_attributes = True