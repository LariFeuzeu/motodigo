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
geo_cache = TTLCache(maxsize=150, ttl=3600)


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

    cache_key = f"{country_code}_{raw_query.lower()}"
    if cache_key in geo_cache:
        return geo_cache[cache_key]

    headers = {
        'User-Agent': 'MotoDigo-App-v1/1.0 (larifeuzeu@gmail.com)',
        'Accept': 'application/json',
    }
    params = {'q': raw_query, 'limit': 10, 'lang': 'fr'}

    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(PHOTON_URL, headers=headers, params=params, timeout=5.0)
            if response.status_code != 200: return []

            data = response.json()
            suggestions = []

            for feature in data.get('features', []):
                props = feature.get('properties', {})

                #  La clé exacte est 'countrycode' sans virgule
                res_country = props.get('countrycode', '').lower()

                # Filtrage strict par pays
                if country_code and res_country != country_code:
                    continue  # On passe au suivant

                name = props.get('name', '')
                city = props.get('city', props.get('state', ''))
                display = f"{name}, {city}" if city and city.lower() != name.lower() else name

                #  L'ajout doit être DANS la boucle for
                suggestions.append(
                    LocationSuggestion(
                        place_id=str(props.get('osm_id', '0')),
                        display_name=display,
                        latitude=float(feature['geometry']['coordinates'][1]),
                        longitude=float(feature['geometry']['coordinates'][0]),
                        country_code=res_country.upper()  # Ajout des parenthèses ()
                    )
                )

            geo_cache[cache_key] = suggestions
            return suggestions
    except Exception as e:
        print(f"🛑 Erreur Photon: {str(e)}")
        return []
