from fastapi import APIRouter, Query, Depends
from app.core.deps import get_current_db_user
from app.db.models import User
from app.services.amadeus import amadeus_client

router = APIRouter(prefix="/airports", tags=["airports"])

@router.get("/search")
async def search_airports(
    q: str = Query(..., min_length=2, description="Search keyword (e.g. 'Tokyo' or 'TYO')"),
    user: User = Depends(get_current_db_user),
):
    results = await amadeus_client.airport_autocomplete(keyword=q)
    return {"query": q, "results": results}