from datetime import datetime, timedelta, timezone  # Classes standard pour manipuler les dates (expiration des tokens).
from typing import Optional, \
    Any  # Annotations de type pour clarifier les paramètres (e.g., paramètre optionnel ou de type variable).
from jose import jwt, JWTError  # Importe la bibliothèque JWT pour l'encodage et le décodage des tokens.
from passlib.context import CryptContext  # Importe la classe pour gérer les options de hachage de mot de passe.
from fastapi.security import OAuth2PasswordBearer
from app.core.config import \
    settings  # Importe l'objet 'settings' pour accéder aux variables de configuration (clés secrètes, durées d'expiration).
from app.database import get_db
from app.crud.crud_user import get_user
from app.shemas.token_shema import TokenPayload
from fastapi import Depends, HTTPException, status
from app.models.user import User
from sqlalchemy.orm import Session

# Indique à FastAPI où trouver le token
oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/token")


# --- Configuration du Hachage de Mot de Passe ---
#  Initialise le contexte de hachage. 'bcrypt' est l'algorithme sécurisé et recommandé.


# Fonctions de Gestion de Jeton (JWT)

def create_access_token(
        subject: str | Any, expires_delta: Optional[timedelta] = None
) -> str:
    """Génère un jeton d'accès JWT de courte durée."""

    #  Vérifie si une durée d'expiration spécifique a été fournie.
    if expires_delta:
        #  Si fournie, la date d'expiration est maintenant (UTC) + la durée spécifique.
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        #  Sinon, utilise la durée par défaut (e.g., 30 minutes) définie dans 'config.py'.
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    #  Construit le 'payload' (charge utile) du jeton.
    # 'exp': L'heure d'expiration (Claim standard JWT).
    # 'sub': Le sujet du token (l'identifiant de l'utilisateur, Claim standard JWT).
    # 'token_type': Utilisé ici pour identifier ce token comme un 'access' token.
    to_encode = {"exp": expire, "sub": str(subject), "token_type": "access"}

    #  Encode le payload en JWT signé en utilisant la clé secrète et l'algorithme (HS256).
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def create_refresh_token(
        subject: str | Any, expires_delta: Optional[timedelta] = None
) -> str:
    """Génère un jeton de rafraîchissement JWT de longue durée (pour renouveler les tokens d'accès)."""

    #  Vérifie si une durée d'expiration spécifique a été fournie.
    if expires_delta:
        #  Si fournie, la date d'expiration est maintenant (UTC) + la durée spécifique.
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        #  Sinon, utilise la durée par défaut (e.g., 7 jours) définie dans 'config.py'.
        expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    #  Construit le 'payload', en marquant ce token comme 'refresh'.
    to_encode = {"exp": expire, "sub": str(subject), "token_type": "refresh"}

    #  Encode le payload en JWT signé.
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


def get_current_user(token: str = Depends(oauth2_scheme),
                     # FastAPI va automatiquement extraire le token JWT de la requête (dans l’en-tête Authorization) grâce à oauth2_scheme
                     db: Session = Depends(get_db)) -> User:
    """Dependance qui verifie jwt et renvoie l'object user"""
    credentials_exception = HTTPException(  # exception HTTP 401 qui sera renvoyée si le token est invalide ou expiré.
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token invalide ou expire.",
        headers={"WWW-Authenticate": "Bearrer"},
    )
    try:
        # decodage du token (verifie la signature et l'expiration )
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )

        # validation du payload " le sub est id du user"
        token_data = TokenPayload(**payload)
        user_id = token_data.sub
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    # recuperation de user dans la db
    user = get_user(db, id=user_id)  # utilisation de la fonction get_user du crud
    if user is None:
        raise credentials_exception
    return user


# Fonction de création du token de réinitialisation de mot de passe
def create_reset_password_token(subject: str, expires_delta: timedelta = None) -> str:
    """Crée un JWT pour la réinitialisation de mot de passe."""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(hours=1)  # token valide 1h par défaut

    to_encode = {"exp": expire, "sub": str(subject), "token_type": "reset"}
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt
