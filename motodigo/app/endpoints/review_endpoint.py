from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.shemas.review import ReviewCreate, ReviewResponse
from app.services import review_service
from app.crud import crud_review
from app.core.security import get_current_user
from app.models.user import User

router = APIRouter()


@router.post("/", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
def add_review(
        review_data: ReviewCreate,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    """Permet à un passager ou à un chauffeur connecté de laisser un avis."""
    return review_service.process_create_review(db=db, review_data=review_data, from_user_id=current_user.id)


@router.get("/user/{user_id}/average")
def get_user_average(user_id: int, db: Session = Depends(get_db)):
    """Récupère la moyenne d'un utilisateur pour l'afficher sur son profil Flutter."""
    average = crud_review.get_user_average_rating(db=db, user_id=user_id)
    return {"user_id": user_id, "average_rating": average}
