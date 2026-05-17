# from sqlalchemy import or_, func
# from sqlalchemy.orm import Session
#
# from app.models import Trip
#
#
# def search_trips_pro(db: Session, user_query_origin: str, user_query_dest: str):
#     # on nettoie la recherche
#
#     q_org = user_query_origin.strip().lower()
#     q_dest = user_query_dest.strip().lower()
#
#     # Soit la ville du chauffeur contient la recherche du user
#     # Soit la recherche du user contient la ville du chauffeur
#     return db.query(Trip).filter(
#         or_(
#             Trip.origin_city.ilike(f"%{q_org}%"),
#             Trip.waypoints.astext.ilike(f"%{q_org}"),
#             func.lower(q_org).contains(func.lower(Trip.origin_name))
#         ),
#         or_(
#             Trip.destination_city.ilike(f"%{q_dest}%"),
#             Trip.waypoints.astext.ilike(f"%{q_dest}%"),
#             func.lower(q_dest).contains(func.lower(Trip.destination_name))
#         )
#     ).all()
