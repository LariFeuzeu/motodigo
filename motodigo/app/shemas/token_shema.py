from pydantic import BaseModel
from typing import Optional


class Token(BaseModel):
    """Structure des tokens retournes apres une connexion reussie"""
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"

    # shema pour la validation


class TokenPayload(BaseModel):
    """ Structure du contenu decode du token """
    sub: Optional[int] = None
    exp: Optional[int] = None
    token_type: Optional[str] = None

# Endpoint pour Swagger uniquement


class SwaggerToken(BaseModel):
    access_token: str
    token_type: str = "bearer"
