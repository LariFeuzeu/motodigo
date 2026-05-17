from sqlalchemy.orm import Session
from app.shemas.vehicule import VehiculeCreate
from app.models.vehicule import Vehicle
from fastapi import HTTPException, status


def create_vehicule(db: Session, vehicule_in: VehiculeCreate, driver_id: int) -> Vehicle:
    """creer un nouveau vehicule et on doit verifier unicite de la plaque."""

    existing_vehicule = db.query(Vehicle).filter(Vehicle.plate == vehicule_in.plate).first()
    if existing_vehicule:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"la plaque d'immatriculation'{vehicule_in.plate}'est deja enregistrée."
        )
    db_vehicule = Vehicle(
        **vehicule_in.model_dump(),
        driver_id=driver_id
    )
    db.add(db_vehicule)
    db.commit()
    db.refresh(db_vehicule)
    return db_vehicule


def update_vehicule_document_url(db: Session, vehicule_id: int, url_type: str, url: str) -> Vehicle:
    """mettre a jour les url de donnee"""
    vehicule = db.query(Vehicle).filter(Vehicle.id == vehicule_id).first()
    if not vehicule:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail=f"vehicule non trouvé")

    if url_type == "registration":
        vehicule.registration_card_url = url
    elif url_type == "inspection":
        vehicule.technical_inspection_url = url
    else:
        raise ValueError("Url non supporte")

    db.commit()
    db.refresh(vehicule)
    return vehicule


def get_vehicules_by_driver(db: Session, driver_id: int):
    return db.query(Vehicle).filter(Vehicle.driver_id == driver_id).all()


def create_vehicule_with_docs(
        db: Session,
        vehicule_in: VehiculeCreate,
        driver_id: int,
        reg_url: str,
        tech_url: str,
        photo_url: str
) -> Vehicle:
    """
    Crée un nouveau véhicule, vérifie l'unicité de la plaque,
    et enregistre immédiatement les URLs des documents (MVP PRO).
    """

    # 1. Vérifier l'unicité de la plaque (Réutilisation de la logique existante)
    # ️ CORRECTION : Vous aviez "filter.plate" au lieu de "Vehicule.plate"
    existing_vehicule = db.query(Vehicle).filter(Vehicle.plate == vehicule_in.plate).first()
    if existing_vehicule:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"la plaque d'immatriculation '{vehicule_in.plate}' est deja enregistrée."
        )

    # 2. Création de l'objet Modèle avec les données de base et les URLs
    db_vehicule = Vehicle(
        **vehicule_in.model_dump(),
        driver_id=driver_id,
        # Ajout des URLs des documents
        registration_card_url=reg_url,
        technical_inspection_url=tech_url,
        vehicle_photo_url=photo_url
        # Assurez-vous que ces noms de colonnes existent dans votre modèle SQLAlchemy Vehicule
    )

    # 3. Enregistrement en base de données
    db.add(db_vehicule)
    #  CORRECTION : Vous aviez db.commmit() (faute de frappe)
    db.commit()
    db.refresh(db_vehicule)

    return db_vehicule
