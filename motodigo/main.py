# main.py
from fastapi import FastAPI, Request
from app.core.config import settings
from app.endpoints import auth
from app.endpoints import user
from app.endpoints import vehicule
from app.endpoints import geocadage
from app.endpoints import trips
from app.endpoints import booking_endpoint
from app.endpoints import review_endpoint
from app.endpoints import messages
import firebase_admin
from firebase_admin import credentials
from fastapi.staticfiles import StaticFiles

from app.web.routes.public_routes import templates

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)
#
#
# # Inclusion des routes Web (HTML)
# app.include_router(public_router)
# app.include_router(admin_router)

app.mount("/static", StaticFiles(directory="app/web/static"), name="static")
app.include_router(auth.router, prefix=f"{settings.API_V1_STR}/auth", tags=["auth"])
app.include_router(user.router, prefix=f"{settings.API_V1_STR}/users", tags=["Users"])
app.include_router(vehicule.router, prefix=f"{settings.API_V1_STR}/vehicule", tags=["Vehicules"])
app.include_router(geocadage.router, prefix=f"{settings.API_V1_STR}/locations", tags=["Geocoding"])
app.include_router(trips.router, prefix=f"{settings.API_V1_STR}/trips", tags=["Trips"])
app.include_router(booking_endpoint.router, prefix=f"{settings.API_V1_STR}/bookings", tags=["Bookings"])
app.include_router(messages.router, prefix=f"{settings.API_V1_STR}/messages", tags=["Messages"])
app.include_router(review_endpoint.router, prefix=f"{settings.API_V1_STR}/review", tags=["Reviews"])


@app.get("/")
async def home(request: Request):
    # Affiche le fichier public/landing_page.html
    return templates.TemplateResponse("public/landing_page.html", {"request": request})

# @app.get("/")
# def read_root():
#     return {"Hey"}

# @app.post("/login", response_model=Token)
# def login(user_id: int):
#     access = create_access_token(subject=user_id)
#     refresh = create_access_token(subject=user_id, expires_delta=timedelta(days=7))
#     return Token(access_token=access, refresh_token = refresh)
# #1. Créer une session de test
# db: Session = SessionLocal()

# # 2. Créer un UserCreate "simulé"
# new_user = UserCreate(
#     full_name="Lari Feuzeu",
#     email="lari@example.com",
#     phone="1234567890",
#     password_hash="motdepasse123",
#     role=UserRole.passenger
# )

# # 3. Appeler la fonction
# user = create_user(db, new_user)

# # 4. Afficher le résultat
# print("Utilisateur créé :", user)
# print("ID :", user.id)
# print("Mot de passe hashé :", user.password_hash)
# db: Session = SessionLocal()
# updateduser = update_user(
#         new_name_user = "michel",
#         new_email_user= "lari@gmail.com",
#         new_phone_user= "67878788"
# )
# new_user = update_user(db, updateduser)
# print(updateduser.full_name)
