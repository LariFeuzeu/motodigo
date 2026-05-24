from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.crud import crud_review
from app.models.trip import Trip
from app.shemas.review import ReviewCreate


def process_create_review(db: Session, review_data: ReviewCreate, from_user_id: int):
    # 1. Sécurité : Interdiction de se noter soi-même
    if from_user_id == review_data.to_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez pas vous donner une note à vous-même."
        )

    #  Vérification  Le trajet existe-t-il
    trip = db.query(Trip).filter(Trip.id == review_data.trip_id).first()
    if not trip:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trajet introuvable."
        )

    # 3. Logique : Le trajet doit être terminé pour être évalué
    if trip.status != "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez émettre un avis que sur un trajet terminé."
        )

    # S'assurer que les deux utilisateurs ont bien participé au trajet
    is_driver_involved = (trip.driver_id == from_user_id or trip.driver_id == review_data.to_user)

    # Extraction des passagers qui ont validé/confirmé leur réservation
    passenger_ids = [b.passenger_id for b in trip.bookings if b.status in ["confirmed", "completed"]]
    is_passenger_involved = (from_user_id in passenger_ids or review_data.to_user in passenger_ids)

    if not (is_driver_involved and is_passenger_involved):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action interdite. Vous n'avez pas partagé ce trajet avec cet utilisateur."
        )

    # Tout est valide, on passe au CRUD
    return crud_review.create_review(db=db, review_data=review_data, from_user_id=from_user_id)