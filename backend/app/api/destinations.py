from fastapi import APIRouter, Query, Depends, HTTPException

from app.core.deps import get_current_db_user
from app.db.models import User
from app.services.places import places_client

router = APIRouter(prefix="/destinations", tags=["destinations"])


@router.get("/search")
async def search_destinations(
    q: str = Query(..., min_length=1),
    user: User = Depends(get_current_db_user),
):
    data = await places_client.search_destination_autocomplete(q)

    results = []

    for p in data.get("suggestions", []):
        place_prediction = p.get("placePrediction", {})
        text = place_prediction.get("text", {}).get("text")
        place_id = place_prediction.get("placeId")

        if not text:
            continue

        parts = [part.strip() for part in text.split(",")]

        results.append({
            "name": text,
            "place_id": place_id,
            "destination_city": parts[0] if len(parts) > 0 else text,
            "destination_country": parts[-1] if len(parts) > 1 else None,
            "destination_iata": None,
        })

    return {
        "query": q,
        "results": results,
    }