from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from sqlalchemy.orm import Session
from cachetools import TTLCache
import httpx

from app.core.security import get_current_user
from app.database import get_db
from app.models.user import User
from app.shemas.location_shema import LocationQuery, LocationSuggestion

router = APIRouter()

PHOTON_URL = "https://photon.komoot.io/api"
geo_cache = TTLCache(maxsize=500, ttl=3600)  # Augmenté pour la production

# OPTIMISATION : Client HTTPX unique et persistant pour garder la connexion chaude
http_client = httpx.AsyncClient(timeout=3.0)

#  DICTIONNAIRE PANAFRICAIN DES FRONTIÈRES (Bounding Boxes)
# Format : "Longitude Min, Latitude Min, Longitude Max, Latitude Max"
AFRICA_BBOXES = {
    # --- AFRIQUE CENTRALE ---
    "cm": "8.49,1.65,16.19,13.07",  # Cameroun (Seul pays actif pour le moment)
    # "ga": "8.69,-3.64,14.53,2.35",      # Gabon
    # "td": "14.41,7.44,24.00,23.50",     # Tchad
    # "cf": "14.41,2.20,27.47,11.01",     # République Centrafricaine
    # "cg": "11.16,-5.03,18.64,3.70",     # Congo-Brazzaville
    # "cd": "12.20,-13.46,31.31,5.39",    # RD Congo
    # "gq": "9.26,0.94,10.93,2.35",       # Guinée Équatoriale
    # "st": "6.31,0.01,7.54,1.71",        # Sao Tomé-et-Principe

    # --- AFRIQUE DE L'OUEST ---
    # "ci": "-8.60,4.35,-2.49,10.73",     # Côte d'Ivoire
    # "sn": "-17.54,12.30,-11.35,16.69",  # Sénégal
    # "tg": "0.14,6.10,1.80,11.14",       # Togo
    # "bj": "0.77,6.23,3.85,12.40",       # Bénin
    # "ng": "2.69,4.27,14.68,13.89",      # Nigeria
    # "gh": "-3.25,4.74,1.19,11.17",      # Ghana
    # "bf": "-5.51,9.40,2.41,15.08",      # Burkina Faso
    # "ml": "-12.24,10.15,4.27,25.00",    # Mali
    # "ne": "0.16,11.70,16.00,23.52",     # Niger
    # "gn": "-15.01,7.19,-7.64,12.68",    # Guinée-Conakry
    # "lr": "-11.51,4.35,-7.37,8.55",     # Liberia
    # "sl": "-13.31,6.92,-10.27,10.00",   # Sierra Leone
    # "gm": "-16.82,13.07,-13.79,13.83",  # Gambie
    # "gw": "-16.71,10.86,-13.63,12.68",  # Guinée-Bissau
    # "cv": "-25.36,14.80,-22.66,17.20",  # Cap-Vert
    # "mr": "-17.07,14.71,-4.83,27.30",   # Mauritanie

    # --- AFRIQUE DU NORD ---
    # "ma": "-17.10,21.33,-1.02,35.92",   # Maroc
    # "dz": "-8.67,18.96,11.99,37.09",    # Algérie
    # "tn": "7.52,30.23,11.59,37.56",     # Tunisie
    # "ly": "9.38,19.51,25.00,33.17",     # Libye
    # "eg": "24.70,22.00,36.90,31.67",    # Égypte
    # "sd": "21.82,9.35,38.60,22.00",     # Soudan

    # --- AFRIQUE DE L'EST ---
    # "ke": "33.91,-4.63,41.91,5.04",     # Kenya
    # "tz": "29.32,-11.74,40.44,-1.00",   # Tanzanie
    # "ug": "29.57,-1.48,35.00,4.23",     # Ouganda
    # "et": "33.00,3.40,48.00,15.00",     # Éthiopie
    # "so": "41.00,-1.65,51.41,12.00",    # Somalie
    # "dj": "41.76,10.98,43.49,12.71",    # Djibouti
    # "er": "36.43,12.36,43.13,18.02",    # Érythrée
    # "rw": "28.86,-2.84,30.90,-1.05",    # Rwanda
    # "bi": "28.99,-4.46,30.85,-2.31",    # Burundi
    # "ss": "23.46,3.49,35.95,12.22",     # Soudan du Sud

    # --- AFRIQUE AUSTRALE & OCÉAN INDIEN ---
    # "za": "16.45,-34.83,32.89,-22.12",  # Afrique du Sud
    # "ao": "11.67,-18.04,24.08,-4.37",   # Angola
    # "mz": "30.21,-26.84,40.84,-10.47",  # Mozambique
    # "zm": "22.00,-18.07,33.70,-8.20",   # Zambie
    # "zw": "25.23,-22.42,33.06,-15.61",  # Zimbabwe
    # "na": "11.74,-28.97,25.26,-16.96",  # Namibie
    # "bw": "20.00,-26.91,29.37,-17.78",  # Botswana
    # "mw": "32.67,-17.13,35.92,-9.36",   # Malawi
    # "ls": "27.01,-30.67,29.47,-28.57",  # Lesotho
    # "sz": "30.79,-27.32,32.14,-25.72",  # Eswatini (Swaziland)
    # "mg": "43.20,-25.60,50.48,-11.95",  # Madagascar
    # "mu": "57.30,-20.52,57.80,-19.98",  # Île Maurice
    # "km": "43.06,-12.42,44.53,-11.36",  # Comores
    # "sc": "55.11,-4.82,55.85,-4.53",    # Seychelles
}


@router.post("/searchlocation", response_model=List[LocationSuggestion])
async def search_locations(
        location_query: LocationQuery,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_user)
):
    raw_query = location_query.query.strip()
    country_code = location_query.country_code.lower().strip()

    if len(raw_query) < 2:
        return []

    # Vérification du cache
    cache_key = f"{country_code}_{raw_query.lower()}"
    if cache_key in geo_cache:
        return geo_cache[cache_key]

    headers = {
        'User-Agent': 'MotoDigo-App-v1/1.0 (larifeuzeu@gmail.com)',
        'Accept': 'application/json',
    }

    # Paramètres initiaux
    params = {'q': raw_query, 'limit': 15, 'lang': 'fr'}

    # Injection dynamique de la Bounding Box si le pays est actif (comme 'cm')
    if country_code in AFRICA_BBOXES:
        params['bbox'] = AFRICA_BBOXES[country_code]

    try:
        # Utilisation du client asynchrone persistant global
        response = await http_client.get(PHOTON_URL, headers=headers, params=params)
        if response.status_code != 200:
            return []

        data = response.json()
        suggestions = []

        for feature in data.get('features', []):
            props = feature.get('properties', {})
            res_country = props.get('countrycode', '').lower()

            # Filtrage strict par pays
            if country_code and res_country != country_code:
                continue

            name = props.get('name', '')
            city = props.get('city', props.get('state', ''))
            display = f"{name}, {city}" if city and city.lower() != name.lower() else name

            # 🔥 SÉCURITÉ : Extraction géométrique protégée contre les structures nulles/incomplètes
            geometry = feature.get('geometry', {})
            coordinates = geometry.get('coordinates', [])

            if len(coordinates) >= 2:
                suggestions.append(
                    LocationSuggestion(
                        place_id=str(props.get('osm_id', '0')),
                        display_name=display,
                        latitude=float(coordinates[1]),
                        longitude=float(coordinates[0]),
                        country_code=res_country.upper()
                    )
                )

        geo_cache[cache_key] = suggestions
        return suggestions

    except Exception as e:
        print(f"🛑 Erreur Photon: {str(e)}")
        return []
