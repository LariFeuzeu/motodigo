from decimal import Decimal
from datetime import datetime, timedelta
from fastapi import HTTPException
from sqlalchemy.orm import Session, joinedload
from app.crud import crud_booking as crud
from app.models import Booking
from app.models.trip import Trip


class BookingService:
    # On définit la commission comme Decimal pour la précision financière
    COMMISSION = Decimal("0.10")

    @classmethod
    def process_booking(cls, db: Session, booking_in, user_id: int):
        trip = db.query(Trip).filter(Trip.id == booking_in.trip_id).first()
        if not trip:
            raise HTTPException(404, "Trajet non trouvé")

        # Correction : On s'assure que seats_available est traité comme un entier
        if int(trip.seats_available) < int(booking_in.seats_booked):
            raise HTTPException(400, "Places insuffisantes")

        try:
            # Calculs financiers avec Decimal
            price_per_seat_dec = Decimal(str(trip.price_per_seat))
            seats_booked_dec = Decimal(str(booking_in.seats_booked))
            total_price = price_per_seat_dec * seats_booked_dec
            fee = total_price * cls.COMMISSION
            driver_amount = total_price - fee

            # 1. Mise à jour du trajet (AVANT le commit)
            trip.seats_available -= booking_in.seats_booked

            # Si tu as fixé Postgres, mets 'full'. Sinon, laisse 'published'.
            if trip.seats_available <= 0:
                trip.status = "full"

                # 2. Création du Booking
            booking_data = {
                "trip_id": trip.id,
                "passenger_id": user_id,
                "seats_booked": booking_in.seats_booked,
                "amount_total": float(total_price),
                "status": "confirmed"
            }
            booking = crud.create_booking_record(db, booking_data)

            # 3. Création de la transaction
            transaction_data = {
                "booking_id": booking.id,
                "amount": float(total_price),
                "platform_fee": float(fee),
                "driver_amount": float(driver_amount),
                "status": "held"
            }
            crud.create_transaction_record(db, transaction_data)

            db.commit()
            booking_final = db.query(Booking) \
                .options(joinedload(Booking.trip)) \
                .filter(Booking.id == booking.id) \
                .first()
            return booking_final

        except Exception as e:
            db.rollback()
            print(f"ERREUR SERVICE BOOKING: {str(e)}")
            raise HTTPException(500, detail=f"Erreur DB: {str(e)}")

    @classmethod
    def process_cancellation(cls, db: Session, booking_id: int, user_id: int):
        booking = crud.get_booking_by_id(db, booking_id)

        if not booking or booking.passenger_id != user_id:
            raise HTTPException(404, "Réservation introuvable")

        # Vérification du délai (12h avant)
        if datetime.now() + timedelta(hours=12) > booking.trip.departure_at:
            raise HTTPException(400, "Annulation impossible moins de 12h avant le départ")

        if booking.status == "cancelled":
            raise HTTPException(400, "Cette réservation est déjà annulée")
        booking.trip.seats_available += booking.seats_booked
        #  Si le trajet était plein, on le réouvre à la vente
        if booking.trip.status == "full":
            booking.trip.status = "published"
        db.commit()
        db.refresh(booking)  # Recharge l'objet avec ses relations
        return booking
