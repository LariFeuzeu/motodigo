from typing import Optional, Any, Dict, Union
from sqlalchemy.orm import Session
from app.models.user import User
from app.shemas.user import UserCreate, UserUpdate
from app.core.utils import get_password_hash


# --- LECTURE (READ) ---

def get_user(db: Session, id: Any) -> Optional[User]:
    """Récupère un utilisateur par son ID (Clé primaire)."""
    return db.query(User).filter(User.id == id).first()


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Récupère un utilisateur par son email."""
    return db.query(User).filter(User.email == email).first()


def get_user_by_phone(db: Session, phone: str) -> Optional[User]:
    """Récupère un utilisateur par son numéro de téléphone."""
    return db.query(User).filter(User.phone == phone).first()


def get_user_by_firebase_uid(db: Session, firebase_uid: str) -> Optional[User]:
    """Recherche un utilisateur par son identifiant unique Firebase."""
    return db.query(User).filter(User.firebase_uid == firebase_uid).first()


def get_user_by_email_or_phone(db: Session, identifier: str) -> Optional[User]:
    """Récupère un utilisateur soit par email, soit par téléphone (utile pour login classique)."""
    return db.query(User).filter(
        (User.email == identifier) | (User.phone == identifier)
    ).first()


# --- CRÉATION (CREATE) ---

def create_user(db: Session, user_in: UserCreate) -> User:
    """Crée un profil utilisateur complet lié à Firebase."""
    # Hachage sécurisé du mot de passe
    hashed_password = get_password_hash(user_in.password_hash)

    db_user = User(
        firebase_uid=user_in.firebase_uid,
        full_name=user_in.full_name,
        email=user_in.email,
        phone=user_in.phone,
        profile_photo_url=user_in.photo_url,
        password_hash=hashed_password,
        role=user_in.role.value if hasattr(user_in.role, 'value') else user_in.role,
        country_code=user_in.country_code
    )

    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


# --- MISES À JOUR (UPDATE) ---

def update_user(db: Session, db_obj: User, obj_in: Union[UserUpdate, Dict[str, Any]]) -> User:
    """Met à jour l'utilisateur de manière flexible (PATCH)."""
    if isinstance(obj_in, dict):
        update_data = obj_in
    else:
        # exclude_unset=True permet de ne mettre à jour que les champs envoyés par Flutter
        update_data = obj_in.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        if field == "password":
            # Si on reçoit un nouveau mot de passe, on le hache
            hashed_password = get_password_hash(value)
            setattr(db_obj, "password_hash", hashed_password)
        elif field == "role" or field == "requested_role":
            # Gestion propre des Enums Pydantic vers String SQL
            val = value.value if hasattr(value, 'value') else value
            setattr(db_obj, field, val)
        else:
            setattr(db_obj, field, value)

    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj


def update_user_firebase_uid(db: Session, user: User, firebase_uid: str) -> User:
    """Lie ou met à jour l'UID Firebase d'un compte existant."""
    user.firebase_uid = firebase_uid
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def update_user_phone(db: Session, user: User, new_phone: str) -> User:
    """Met à jour le numéro de téléphone après validation SMS."""
    user.phone = new_phone
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def update_user_password(db: Session, user: User, new_password: str) -> User:
    """Réinitialisation du mot de passe (Forgot Password)."""
    user.password_hash = get_password_hash(new_password)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user
