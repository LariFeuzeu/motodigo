from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, text
from sqlalchemy.orm import Session
from typing import List, Optional
from sqlalchemy.orm import joinedload

from app import models
from app.database import get_db
from app.models.trip import Trip
from app.models.user import User
from app.core.security import get_current_user
from app.shemas.trips_schema import TripCreate, TripRead
from app.models.booking import Booking
from sqlalchemy import or_, cast, Text

router = APIRouter()


# CREATE EXTENSION IF NOT EXISTS pg_trgm;

@router.post("/", response_model=TripRead, status_code=status.HTTP_201_CREATED)
async def create_trip(
        trip_in: TripCreate,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    print(f"DEBUG: ID de l'utilisateur : {current_user.id}")
    print(f"DEBUG: Rôle reçu du Token : '{current_user.role}'")
    if current_user.role != "driver":
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Seuls les chauffeurs peuvent publier.")

    try:
        # Extraire les données du schéma en dictionnaire
        trip_data = trip_in.model_dump()

        # On retire seats_available s'il existe pour éviter le conflit lors du double passage
        trip_data.pop('driver_name', None)
        trip_data.pop('vehicle_model', None)
        trip_data.pop('seats_available', None)

        new_trip = Trip(
            **trip_data,
            driver_id=current_user.id,
            seats_available=trip_in.seats_total,  # On s'assure qu'au départ, dispo = total
            status='published'
        )

        db.add(new_trip)
        db.commit()
        db.refresh(new_trip)
        return new_trip
    except Exception as e:
        db.rollback()
        print(f"❌ ERREUR SERVEUR TRIP: {e}")  # Debugging
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/meTrips", response_model=List[TripRead])
async def get_my_trip(
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    """Récupérer tous les trajets publiés par le chauffeur connecté"""
    return db.query(Trip).filter(Trip.driver_id == current_user.id).all()


@router.delete("/{trip_id}/cancel")
async def cancel_trip(
        trip_id: int,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    """Permet au chauffeur d'annuler son trajet"""

    trip = db.query(Trip).filter(
        Trip.id == trip_id,
        Trip.driver_id == current_user.id
    ).first()

    if not trip:
        raise HTTPException(status_code=404, detail="Trajet non trouvé")

    if trip.driver_id != current_user.id:
        raise HTTPException(status_code=403, detail="Action non autorisee")
    try:
        # AU LIEU DE db.delete(trip), ON FAIT UN UPDATE
        trip.status = "cancelled"  # <--- On change juste le mot

        #  On annule aussi les réservations liées pour libérer les passagers
        db.query(models.Booking).filter(models.Booking.trip_id == trip_id).update({"status": "cancelled"})

        db.commit()
        return {"message": "Le trajet a été annulé avec succès"}

    except Exception as e:
        db.rollback()
        # On log l'erreur précise pour débugger
        print(f"ERREUR DÉTAILLÉE : {e}")
        raise HTTPException(status_code=500, detail=f"Erreur DB: {str(e)}")


@router.get("/{trip_id}/passengers")
async def get_trip_passengers(trip_id: int, db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    try:
        # jointure d'un passager a un trajet
        query = text("""
            SELECT u.id as user_id, u.full_name, b.seats_booked, b.status, u.phone
            FROM bookings b
            JOIN users u ON b.passenger_id = u.id
            WHERE b.trip_id = :tid AND b.status = 'confirmed'
        """)

        result = db.execute(query, {"tid": trip_id})

        # Mapping manuel pour éviter l'erreur "TypeError: dict() argument must be..."
        passengers = []
        for row in result:
            passengers.append({
                "user_id": row.user_id,
                "full_name": row.full_name,
                "seats_booked": row.seats_booked,
                "status": row.status,
                "phone": row.phone
            })

        return passengers

    except Exception as e:
        print(f"🛑 Erreur SQL Passengers: {str(e)}")
        # On renvoie une liste vide au lieu d'une 500 pour ne pas faire crash Flutter
        return []


@router.get("/searchTrip", response_model=List[TripRead])
async def search_trip(
        origin: str,
        destination: str,
        country_code: str,
        date: Optional[str] = None,
        seats: int = 1,
        db: Session = Depends(get_db)
):
    #  Base de la requête (Jointures incluses pour le style Premium)
    query = db.query(Trip).options(
        joinedload(Trip.driver),
        joinedload(Trip.vehicle)
    ).filter(
        Trip.status == 'published',
        Trip.seats_available >= seats,
        Trip.country_code == country_code.upper(),
        Trip.departure_at >= datetime.now()
    )

    #  Logique de Recherche Transversale (Départ/Escales -> Escales/Arrivée)
    # On nettoie les entrées

    q_org = f"%{origin.strip()}%"
    q_dest = f"%{destination.strip()}%"

    # Filtre ORIGINE : La ville est soit le départ, soit dans les waypoints
    origin_filter = or_(
        Trip.origin_city.ilike(q_org),
        cast(Trip.waypoints, Text).ilike(q_org)
    )

    # Filtre DESTINATION : La ville est soit l'arrivée, soit dans les waypoints
    destination_filter = or_(
        Trip.destination_city.ilike(q_dest),
        cast(Trip.waypoints, Text).ilike(q_dest)
    )

    # On applique les deux filtres pour s'assurer que le trajet contient LES DEUX
    query = query.filter(origin_filter).filter(destination_filter)

    #  Filtre par date
    if date:
        query = query.filter(func.date(Trip.departure_at) == date)

    trips = query.all()

    #  Préparation des données pour le Schéma TripRead (Clean Architecture)
    for trip in trips:
        trip.driver_name = trip.driver.full_name if trip.driver else "Chauffeur"
    if trip.vehicle:
        trip.vehicle_model = f"{trip.vehicle.make or ''} {trip.vehicle.model_name or ''}".strip()
    else:
        trip.vehicle_model = "Véhicule"

    return trips
