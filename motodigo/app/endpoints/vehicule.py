from fastapi import APIRouter, Depends, status, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from typing import List
from app.shemas.user import UserUpdate, UserShema, UserRole
from app.database import get_db
from app.crud import crud_user
from app.crud import crud_vehicule
from app.models.user import User
from app.shemas.vehicule import VehiculeCreate, VehiculeShema
from app.core.security import get_current_user

router = APIRouter()


@router.post("/register_full", response_model=VehiculeShema, status_code=status.HTTP_201_CREATED)
async def register_vehicule_full(
        # 1. Données du véhicule (Reçues via Form)

        plate: str = Form(..., max_length=15),
        model: str = Form(..., alias='model'),  # Utilise 'model_name' si c'est le champ du schéma
        color: str = Form(...),
        seats: int = Form(..., gt=0, le=8),  # Utilisez 'seats' si c'est le champ du schéma

        #  Documents (Fichiers Uploadés)
        registration_card: UploadFile = File(..., description="Carte Grise / Certificat d'Immatriculation"),
        technical_inspection: UploadFile = File(..., description="Contrôle Technique / Assurance"),
        vehicle_photo: UploadFile = File(..., description="Photo du véhicule"),

        # Dépendances
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    #  Vérification du Rôle
    if current_user.role == UserRole.driver:
        # Pour l'MVP, on bloque l'utilisation de cette route si déjà chauffeur
        raise HTTPException(status.HTTP_400_BAD_REQUEST,
                            detail="Vous êtes déjà chauffeur. Utilisez une route séparée pour ajouter d'autres véhicules.")

    if current_user.role != UserRole.passenger:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Rôle utilisateur non autorisé pour la conversion.")

    #  LOGIQUE DE TÉLÉVERSEMENT
    if registration_card.size == 0 or technical_inspection.size == 0:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Les deux documents sont requis.")

    # Simulation de l'upload (URL Fictive)
    reg_url = f"/storage/reg_card/{current_user.id}_{registration_card.filename}"
    tech_url = f"/storage/tech_insp/{current_user.id}_{technical_inspection.filename}"
    photo_url = f"/storage/vehicles/{current_user.id}_photo_{vehicle_photo.filename}"

    #  Création du Véhicule
    # Nous devons reconstruire l'objet VehiculeCreate pour le CRUD
    vehicule_in = VehiculeCreate(
        plate=plate,
        model_name=model,
        photo_url=photo_url,
        color=color,
        seats=seats
        # Assurez-vous que le schéma VehiculeCreate est correctement adapté aux champs ci-dessus
    )

    try:
        # Vous devez adapter crud_vehicule.create_vehicule pour accepter les URLs des documents
        # OU créer une nouvelle fonction CRUD si nécessaire
        db_vehicule = crud_vehicule.create_vehicule_with_docs(
            db,
            vehicule_in=vehicule_in,
            driver_id=current_user.id,
            reg_url=reg_url,
            tech_url=tech_url
        )
    except Exception as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail=f"Erreur d'enregistrement du véhicule: {str(e)}")

    #   PROMOTION IMMÉDIATE DU RÔLE (MVP PRO)
    crud_user.update_user(
        db,
        db_obj=current_user,
        obj_in={
            'role': UserRole.driver,
            'requested_role': None  # Nettoie l'ancien statut si il existait
        }
    )

    return db_vehicule


@router.get("/list_vehicule", response_model=List[VehiculeShema])
async def read_my_vehicule(
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    """Affiche la liste de vehicule enregistrer par le chauffeur """
    if current_user.role != "driver":
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Acces refuse.")

    vehicules = crud_vehicule.get_vehicules_by_driver(db, driver_id=current_user.id)
    return vehicules
