from sqlalchemy.orm import Session
from sqlalchemy.sql import func
from app.models.review import Review
from app.shemas.review import ReviewCreate


def create_review(db: Session, review_data: ReviewCreate, from_user_id: int) -> Review:
    """Enregistrer un avis en base"""
    db_review = Review(
        trip_id=review_data.trip_id,
        from_user=from_user_id,
        to_user=review_data.to_user,
        rating=review_data.rating,
        comment=review_data

    )
    db.add(db_review)
    db.commit()
    db.refresh(db_review)
    return db_review


def get_user_average_rating(db: Session, user_id: int) -> float:
    """Calcule la note moyenne des avis recus par un utilisateur """

    result = db.query(func.avg(Review.rating)).filter(Review.to_user == user_id).scalar()
    return round(float(result), 1) if result is not None else 5.0
