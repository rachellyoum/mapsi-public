from app.core.config import settings


if not settings.GOOGLE_MAPS_API_KEY:
    raise RuntimeError("GOOGLE_MAPS_API_KEY not set")

base_url = "https://places.googleapis.com/v1"
api_key = settings.GOOGLE_MAPS_API_KEY

def build_photo_url(photo_ref: str, max_height: int = 400) -> str:
    return (
        f"{base_url}/{photo_ref}/media"
        f"?maxHeightPx={max_height}&key={api_key}"
    )