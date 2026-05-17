from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, text
from sqlalchemy.orm import Session
from typing import List, Optional
from sqlalchemy.orm import joinedload
from app.database import get_db
from app.models.message import Message
from app.models.trip import Trip
from app.models.user import User
from app.core.security import get_current_user
from app.shemas.message_shema import MessageRead, MessageCreate
from app.models.booking import Booking

router = APIRouter()


@router.post("/", response_model=MessageRead)
async def send_message(
        msg_in: MessageCreate,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    # Sécurité : On vérifie si le trajet existe avant d'envoyer
    trip = db.query(Trip).filter(Trip.id == msg_in.trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trajet non trouvé")
    new_msg = Message(
        **msg_in.model_dump(),
        sender_id=current_user.id,
    )
    db.add(new_msg)
    db.commit()
    db.refresh(new_msg)
    return new_msg


@router.get("/discussions")
async def get_user_discussions(db: Session = Depends(get_db), current_user=Depends(get_current_user)):
    discussions = db.execute(text("""
        SELECT DISTINCT ON (m.trip_id) 
            m.trip_id, m.content as last_message, m.created_at,
            u.full_name as other_user_name, u.id as other_user_id
        FROM messages m
        JOIN users u ON (u.id = m.sender_id OR u.id = m.receiver_id)
        WHERE (m.sender_id = :uid OR m.receiver_id = :uid)
        AND u.id != :uid
        ORDER BY m.trip_id, m.created_at DESC
    """), {"uid": current_user.id}).fetchall()
    return [dict(row) for row in discussions]


@router.get("/{trip_id}", response_model=List[MessageRead])
async def get_trip_messages(
        trip_id: int,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    """
        Récupère tous les messages liés à un trajet spécifique.
        On vérifie que l'utilisateur fait bien partie du trajet soit chauffeur, soit passager.
        """

    # on verifie si le trajet existe
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trajet non trouve")
    # confidentialte
    is_driver = trip.driver_id == current_user.id

    # On verifie si user a une reservation pour ce trajet

    is_passager = db.query(Booking).filter(
        Booking.trip_id == trip_id,
        Booking.passenger_id == current_user.id,
        Booking.status == "Confirmed"  # on laisse lire ce qui est confirme
    ).first() is not None

    # si le user nest ni un chauffeur ou un passager
    if not is_driver and not is_passager:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Acces refuser')

    # recuperation des messages
    # le anti slash est pour continuer a la ligne
    messages = db.query(Message) \
        .filter(Message.trip_id == trip_id) \
        .order_by(Message.created_at.asc()) \
        .all()
    # marquer comme lu

    db.query(Message).filter(
        Message.trip_id == trip_id,
        Message.receiver_id == current_user.id,
        Message.is_read == False
    ).update({"is_read": True})

    db.commit()
    return messages
