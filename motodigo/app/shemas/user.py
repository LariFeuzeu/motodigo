from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List
from datetime import datetime
from enum import Enum
from app.shemas.vehicule import VehiculeShema


# Définition des rôles possibles (bonne pratique)
class UserRole(str, Enum):
    """Enum pour garantir que le rôle est valide."""
    passenger = "passenger"
    driver = "driver"


class DriverRequestStatus(str, Enum):
    en_attente = "en_attente"
    en_cours = "en_cours"
    confirmee = "confirmée"


# Modèle de base pour la lecture (champs communs)
class UserBase(BaseModel):
    full_name: str
    email: Optional[EmailStr] = None  # Utilise EmailStr de Pydantic pour la validation du format
    phone: str = Field(..., min_length=8, max_length=15)  # Validation de la longueur du téléphone
    role: UserRole  # Force l'utilisateur à choisir un rôle valide de l'Enum
    country_code: Optional[str] = Field(None, min_length=2, max_length=2)
    photo_url: str


# Modèle pour l'Inscription (Création)
class UserCreate(UserBase):
    """Schéma d'entrée pour la création d'un nouvel utilisateur."""
    password_hash: str = Field(..., min_length=8)  # Le mot de passe est obligatoire et doit être haché
    firebase_uid: str


class UserUpdates(UserBase):
    password: Optional[str] = None
    # autres champs...


# Modèle pour la Mise à Jour (rend tous les champs optionnels)
class UserUpdate(UserBase):
    """Schéma d'entrée pour la mise à jour des données utilisateur."""
    # Surcharge les champs de UserBase pour les rendre optionnels
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    requested_role: Optional[UserRole] = None
    password_hash: Optional[str] = Field(None, min_length=8)
    profile_photo_url: Optional[str] = None


# Modèle de Réponse (Sortie de l'API)
class UserShema(UserBase):
    """Schéma de sortie utilisé pour retourner les données de l'utilisateur."""
    id: int
    profile_photo_url: Optional[str] = None
    requested_role: Optional[UserRole] = None
    driver_request_status: Optional[DriverRequestStatus] = None
    created_at: datetime
    message: Optional[str] = None
    vehicles: List[VehiculeShema] = Field(default=[], alias="vehicules")

    class Config:
        # Permet à Pydantic de lire les données directement à partir d'un objet SQLAlchemy ORM et reponse en json
        from_attributes = True
        populate_by_name = True  # Important pour que l'alias fonctionne
