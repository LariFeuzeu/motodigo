from passlib.context import CryptContext
from fastapi import UploadFile
import shutil
import os

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# Fonctions de Hachage (Bcrypt)


def get_password_hash(password: str) -> str:
    """Hache un mot de passe en texte clair (lors de l'inscription)."""
    # 7. La méthode .hash() applique Bcrypt, y compris le salage automatique, et retourne le hachage sécurisé.
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Vérifie si le mot de passe en clair correspond au hachage stocké (lors de la connexion)."""
    # 8. Hache le 'plain_password' donné et le compare au 'hashed_password' de la DB. Retourne True ou False.
    return pwd_context.verify(plain_password, hashed_password)


def save_profile_photo(profile_photo: UploadFile, firebase_uid: str) -> str:
    UPLOAD_DIR = "static/profiles"
    os.makedirs(UPLOAD_DIR, exist_ok=True)
    file_extension = os.path.splitext(profile_photo.filename)[1]
    file_name = f"{firebase_uid}{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, file_name)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(profile_photo.file, buffer)

    return f"/static/profiles/{file_name}"