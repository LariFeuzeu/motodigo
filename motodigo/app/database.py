from sqlalchemy import create_engine #connexion entre le code python et la db
from sqlalchemy.orm import sessionmaker #creation de session de db
from sqlalchemy.ext.declarative import declarative_base #classede base pour creation des models
from app.core.config import settings #import desparams de config
from typing import Generator # description dune fonctionne qui renvoie temporairement une valeur (yield)
from sqlalchemy.orm import Session 

#moteur engine point de connexion avec la db 
engine = create_engine(
    settings.SQLACHEMY_DATABASE_URL,
    pool_pre_ping = True #pour maintenir la connexion active
 )
 #session de travail
SessionLocal = sessionmaker(
    autocommit = False,
    autoflush = False, #controle des requetes
    bind=engine    # relie session a la base
 )
# les models heriterons de cette base
Base  = declarative_base()

def get_db() ->Generator [Session, None, None]:
    """
    Dépendance utilisée dans les routes FastAPI pour obtenir une session DB.
    Garantit que la session est fermée après la requête (bloc 'finally').
    """
    db = SessionLocal()
    try:
        yield db #Cède la session à la fonction de route 
    finally :
        db.close() 