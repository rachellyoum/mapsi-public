import logging
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import RedirectResponse
from app.services.media import build_photo_url
from app.services.pois import get_pois

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/media", tags=["media"])


@router.get("/photos")
async def get_photo(photo_ref: str, max_height: int = 400):
    if not photo_ref:
        raise HTTPException(status_code=400, detail="Missing photo_ref")

    url = build_photo_url(photo_ref, max_height)
    return RedirectResponse(url)


@router.get("/city-photo")
async def get_city_photo(city: str, request: Request):
    try:
        query = f"top landmarks in {city}"

        pois, _ = await get_pois(query, max_results=1)

        if not pois:
            query = f"{city} skyline"
            pois, _ = await get_pois(query, max_results=1)

            if not pois:
                query = f"{city}"
                pois, _ = await get_pois(query, max_results=1)
                
                if not pois:
                    return {"photo_url": None}

        poi = pois[0]
        photos = poi.get("photos") or []

        photo_ref = None
        if isinstance(photos, list) and len(photos) > 0:
            first_photo = photos[0]
            if isinstance(first_photo, dict):
                photo_ref = first_photo.get("name")

        if photo_ref:
            base = str(request.base_url).rstrip("/")
            return {"photo_url": f"{base}/media/photos?photo_ref={photo_ref}"}
        
        return {"photo_url": None}
    
    except Exception as e:
        logger.exception(f"Error fetching city photo for {city}: {e}")
        return {"photo_url": None}