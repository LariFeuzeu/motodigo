from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session, joinedload
from app.database import get_db
from app.models.user import User
from app.shemas.user import UserUpdate, UserShema, UserRole  # Import de l'Enum Role
from app.crud import crud_user
from app.core.security import get_current_user
from app.shemas import DriverRequestStatus
from app.core.utils import get_password_hash

router = APIRouter()


@router.patch("/me/", response_model=UserShema)
async def update_user_me(
        user_in: UserUpdate,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    """
    Met à jour le profil PATCH. Gère la demande de rôle 'driver' par l'utilisateur.
    """

    update_data = user_in.model_dump(exclude_unset=True)
    "Modification du mot de passe on le hash avant d'enregistrer"
    if user_in.password:
        update_data['password_hash'] = get_password_hash(user_in.password)
    # 1. LOGIQUE CRITIQUE : Interception du changement de rôle

    if 'role' in update_data:
        # Un utilisateur ne peut JAMAIS modifier son champ role directement.
        # Seul un Admin peut le faire après validation.
        del update_data['role']  # on ignore la demande

    if 'requested_role' in update_data and update_data[
        'requested_role'] == UserRole.driver:  # on verifie ci le user a fait une demande et on verifie ci la valeur demander est diver

        # L'utilisateur essaie de passer à 'driver'
        if current_user.role == UserRole.driver or current_user.requested_role == UserRole.driver:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Demande de rôle déjà en cours ou complétée.")

        update_data['requested_role'] = UserRole.driver
        update_data['driver_requested_role'] = DriverRequestStatus.en_attente
        # Lancement de la procédure de validation : le champ est mis à jour.
        print(f"\n[PROCÉDURE CHAUFFEUR] Utilisateur {current_user.id} a demandé le rôle 'driver'.")
        # Le code continuera pour mettre à jour ce champ dans la DB via le CRUD.

    # Si l'utilisateur n'a soumis aucune donnée valide (ex: seulement 'role'), on ne fait rien.
    if not update_data:
        return current_user

        # 2. Appel de la fonction CRUD FLEXIBLE
    updated_user = crud_user.update_user(db, db_obj=current_user, obj_in=update_data)

    # Information pour le client Flutter après la mise à jour
    if updated_user.requested_role == UserRole.driver:
        # Ceci est le message pour l'interface utilisateur
        updated_user.message = "Votre demande de rôle 'Chauffeur' est enregistrée. Veuillez maintenant enregistrer votre véhicule et téléverser vos documents pour la validation."

    return updated_user


@router.get("/me/", response_model=UserShema)
async def read_user_me(
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user),
):
    user_with_vehicles = db.query(User).options(joinedload(User.vehicules),joinedload(User.reviews_received)).filter(User.id == current_user.id).first()
    """Récupération du profil de l'utilisateur authentifié."""
    return user_with_vehicles
