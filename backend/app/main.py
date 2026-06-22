"""
main.py

Entry point of the FastAPI application.

- Creates the FastAPI app instance
- Initializes Firebase and database on startup
- Registers all API routers
- Defines global app configuration

This file is where the backend server starts.
"""


from fastapi import FastAPI
from app.core.config import settings
from app.api.health import router as health_router
from app.core.firebase import init_firebase
from app.api.me import router as me_router
from app.db.database import engine
from app.db.models import Base
from app.api.trips import router as trips_router
from app.api.flights import router as flights_router
from app.api.airports import router as airports_router
from app.api.places import router as places_router
from app.api.itinerary import router as itinerary_router
from app.api.users import router as users_router
from app.api.media import router as media_router
from app.api.friends import router as friends_router
from app.api.destinations import router as destinations_router

import os
import uvicorn

app = FastAPI(title="Maps i Travel Planner API", version="0.1.0")

@app.on_event("startup")
async def startup():
    init_firebase()

    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        print("Database initialized successfully!")
    except Exception as e:
        print(f"Warning: database init failed: {e}")

app.include_router(health_router)
app.include_router(me_router)
app.include_router(trips_router)
app.include_router(flights_router)
app.include_router(airports_router)
app.include_router(places_router)
app.include_router(itinerary_router)
app.include_router(users_router)
app.include_router(media_router)
app.include_router(friends_router)
app.include_router(destinations_router)

@app.get("/")
def root():
    return {"name": "Maps i Travel Planner API"} #, "env": settings.ENV

# if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))  # use Cloud Run's PORT or default to 8000
    uvicorn.run("app.main:app", host="0.0.0.0", port=port)