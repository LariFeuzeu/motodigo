from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from jose import jwt, JWTError
from pydantic import BaseModel, Field
from typing import Optional

# Firebase Admin SDK
from firebase_admin import auth as firebase_auth

# Tes imports de couches Clean Architecture
from app.database import get_db
from app.shemas.user import UserCreate, UserShema
from app.shemas.token_shema import Token, TokenPayload
from app.crud import crud_user
from app.core.utils import save_profile_photo
from app.core.utils import verify_password
from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token, create_reset_password_token

router = APIRouter()


# --- SCHÉMAS DE DONNÉES (Pydantic) ---

class FirebaseLogin(BaseModel):
    """Schéma pour recevoir la preuve de connexion de Firebase (Flutter)"""
    id_token: str


class PasswordResetRequest(BaseModel):
    """Pour la demande de réinitialisation via Email"""
    identifier: str


class PasswordReset(BaseModel):
    """Pour valider le nouveau mot de passe avec le token"""
    token: str
    new_password: str = Field(..., min_length=8)


# --- ENDPOINTS ---
@router.post("/login/firebase", response_model=Token)
async def login_with_firebase(data: FirebaseLogin, db: Session = Depends(get_db)):
    print("1. Requête reçue, vérification du token Firebase...")
    try:
        # 1. Validation du token auprès de Google
        decoded_token = firebase_auth.verify_id_token(data.id_token)

        # 2. Extraction des infos clés
        firebase_uid = decoded_token.get("uid")  # L'identifiant immuable
        phone = decoded_token.get("phone_number")

        if not firebase_uid:
            raise HTTPException(status_code=401, detail="Token Firebase invalide : UID manquant")

        #  Recherche par UID (Beaucoup plus fiable que le téléphone)
        user = crud_user.get_user_by_firebase_uid(db, firebase_uid=firebase_uid)
        print(f"3. Recherche terminée. Utilisateur trouvé : {user is not None}")
        if not user:
            # Si pas d'UID, on peut tenter une recherche par téléphone pour "recoller"
            # d'anciens comptes si tu avais déjà des utilisateurs sans UID
            user = crud_user.get_user_by_phone(db, phone=phone)

            if user:
                # Si on le trouve par tel, on en profite pour enregistrer son UID
                crud_user.update_user_firebase_uid(db, user=user, firebase_uid=firebase_uid)
            else:
                # Sinon, direction l'écran Register de Flutter
                raise HTTPException(status_code=404, detail="USER_NOT_FOUND")

        # 4. Optionnel : Mise à jour du numéro de téléphone si Firebase en a un nouveau
        if phone and user.phone != phone:
            crud_user.update_user_phone(db, user=user, new_phone=phone)

        # 5. Génération des tokens Empire
        access_token = create_access_token(subject=str(user.id))
        refresh_token = create_refresh_token(subject=str(user.id))

        return Token(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer"
        )

    except Exception as e:
        print(f"Détail technique de l'erreur Firebase : {e}")
        if "USER_NOT_FOUND" in str(e):
            raise e
        raise HTTPException(status_code=401, detail=f"Session Firebase invalide : {str(e)}")


@router.post("/register", response_model=Token)
async def register_user(
        full_name: str = Form(...),
        email: str = Form(...),
        phone: str = Form(...),
        password: str = Form(...),
        role: str = Form(...),
        firebase_uid: str = Form(...),
        country_code: str = Form(...),
        profile_photo: UploadFile = File(...),
        db: Session = Depends(get_db)
):
    #  Vérifications d'usage
    if crud_user.get_user_by_email(db, email=email):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="E-mail déjà enregistré.")
    if crud_user.get_user_by_phone(db, phone=phone):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Téléphone déjà enregistré.")

    #  Sauvegarde du fichier
    photo_url = save_profile_photo(profile_photo, firebase_uid)

    #  Préparation du schéma pour le CRUD
    user_in = UserCreate(
        full_name=full_name,
        email=email,
        phone=phone,
        role=role,
        password_hash=password,  # Sera haché dans le CRUD
        firebase_uid=firebase_uid,
        country_code=country_code,
        photo_url=photo_url
    )

    #  Création de l'utilisateur
    user = crud_user.create_user(db, user_in=user_in)

    #  Génération des tokens
    access_token = create_access_token(subject=str(user.id))
    refresh_token = create_refresh_token(subject=str(user.id))

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer"
    )


# @router.post("/register", response_model=Token)  # Change UserShema en Token
# async def register_user(user_in: UserCreate, db: Session = Depends(get_db)):
#     #  Vérifications d'usage
#     if crud_user.get_user_by_email(db, email=user_in.email):
#         raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="E-mail déjà enregistré.")
#     if crud_user.get_user_by_phone(db, phone=user_in.phone):
#         raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Téléphone déjà enregistré.")
#
#         full_name: str = Form(...),
#         email: str = Form(...),
#         phone: str = Form(...),
#         password: str = Form(...),
#         role: str = Form(...),
#         firebase_uid: str = Form(...),
#         country_code: str = Form(...),
#         profile_photo: UploadFile = File(...),  # Reçu ici
#         db: Session = Depends(get_db)
#
#     ):
#     # 1. Vérifications (E-mail / Phone)
#     if crud_user.get_user_by_email(db, email=email):
#         raise HTTPException(400, detail="E-mail déjà enregistré.")
#
#     # 2. Sauvegarde du fichier (On peut créer une petite fonction utilitaire pour ça)
#     photo_url = save_profile_photo(profile_photo, firebase_uid)
#
#     # 3. On prépare le schéma pour le CRUD
#     user_in = UserCreate(
#         full_name=full_name,
#         email=email,
#         phone=phone,
#         role=role,
#         password_hash=password,
#         firebase_uid=firebase_uid,
#         country_code=country_code,
#         photo_url=photo_url  # L'URL générée est passée ici
#     )
#
#     # 4. Appel de TON CRUD tel quel
#     user = crud_user.create_user(db, user_in=user_in)
#
#     #  GÉNÉRATION DES TOKENS (Pour que Flutter soit content)
#     access_token = create_access_token(subject=str(user.id))
#     refresh_token = create_refresh_token(subject=str(user.id))
#
#     return Token(
#         access_token=access_token,
#         refresh_token=refresh_token,
#         token_type="bearer"
#     )


@router.post("/token", response_model=Token)
async def login_standard(
        form_data: OAuth2PasswordRequestForm = Depends(),
        db: Session = Depends(get_db)
):
    """
    Connexion classique (Email/Password) - Utile pour le mode debug ou admin.
    """
    user = crud_user.get_user_by_email_or_phone(db, form_data.username)

    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Identifiants incorrects.")

    access_token = create_access_token(subject=str(user.id))
    refresh_token = create_refresh_token(subject=str(user.id))

    return Token(access_token=access_token, refresh_token=refresh_token, token_type="bearer")


@router.post("/refresh")
def refresh_access_token(refresh_token: str):
    """
    rotation du token on valide ancien on donne nouveau
    """
    try:
        # decode on verifie si cest bien du refresh token
        payload = jwt.decode(refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])

        if payload.get("token_type") != "refresh":
            raise HTTPException(status_code=401, detail="Ce n'est pas un Refresh Token valide")

        user_id = payload.get("sub")

        # On génère un nouveau couple de tokens (Sécurité maximale)
        new_access_token = create_access_token(subject=user_id)
        new_refresh_token = create_refresh_token(subject=user_id)

        return {
            "access_token": new_access_token,
            "refresh_token": new_refresh_token,
            "token_type": "bearer"
        }
    except JWTError:
        raise HTTPException(status_code=401, detail="Session expirée, merci de vous reconnecter")


@router.post("/forgot-password", status_code=status.HTTP_202_ACCEPTED)
async def request_password_reset(request: PasswordResetRequest, db: Session = Depends(get_db)):
    """
    Système de secours : Envoie un lien de récupération par Email si le téléphone est perdu.
    """
    user = crud_user.get_user_by_email_or_phone(db, identifier=request.identifier)

    if not user:
        # On ne confirme pas que l'email n'existe pas (Sécurité)
        return {"message": "Si le compte existe, un lien a été envoyé."}

    # Génération d'un token spécial 'reset'
    reset_token = create_reset_password_token(subject=str(user.id))

    # SIMULATION : Ici tu intégrerais SendGrid ou Mailgun pour envoyer le lien
    print(f"--- [EMAIL SENT] --- Token de récupération pour {user.email} : {reset_token}")

    return {"message": "Lien de réinitialisation créé. Vérifiez vos emails."}


@router.post("/reset-password", response_model=UserShema)
async def reset_password(data: PasswordReset, db: Session = Depends(get_db)):
    """
    Valide le changement de mot de passe après clic sur le lien email.
    """
    try:
        payload = jwt.decode(data.token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        if payload.get("token_type") != "reset":
            raise HTTPException(status_code=401, detail="Token de type incorrect")

        user_id = payload.get("sub")
    except JWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Lien expiré ou invalide")

    user = crud_user.get_user(db, id=user_id)
    if not user:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Utilisateur introuvable")

    # Mise à jour du mot de passe dans la DB
    return crud_user.update_user_password(db, user=user, new_password=data.new_password)
