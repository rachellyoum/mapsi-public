import httpx
from app.core.config import settings


class GooglePlacesClient:
    def __init__(self) -> None:
        if not settings.GOOGLE_MAPS_API_KEY:
            raise RuntimeError("GOOGLE_MAPS_API_KEY not set")

        self.base_url = "https://places.googleapis.com/v1"
        self.api_key = settings.GOOGLE_MAPS_API_KEY

    def build_maps_link(self, place_id: str) -> str:
        return f"https://www.google.com/maps/place/?q=place_id:{place_id}"

    async def search_text(
        self,
        query: str,
        max_results: int = 10,
    ) -> dict:
        url = f"{self.base_url}/places:searchText"

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.api_key,
            "X-Goog-FieldMask": (
                "places.id,"
                "places.displayName,"
                "places.formattedAddress,"
                "places.rating,"
                "places.priceLevel,"
                "places.types,"
                "places.location,"
                "places.photos,"
                "places.regularOpeningHours"
            ),
        }

        body = {
            "textQuery": query,
            "pageSize": max_results,
        }

        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(url, headers=headers, json=body)
            resp.raise_for_status()
            return resp.json()

    async def get_place_details(self, place_id: str) -> dict:
        url = f"{self.base_url}/places/{place_id}"

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.api_key,
            "X-Goog-FieldMask": (
                "id,"
                "displayName,"
                "formattedAddress,"
                "rating,"
                "priceLevel,"
                "types,"
                "location,"
                "photos,"
                "websiteUri,"
                "googleMapsUri,"
                "regularOpeningHours,"
                "currentOpeningHours,"
                "reviews"
            ),
        }

        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.get(url, headers=headers)
            resp.raise_for_status()
            return resp.json()
        
    async def search_destinations(
        self,
        query: str,
        max_results: int = 10,
    ) -> dict:
        url = f"{self.base_url}/places:searchText"

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.api_key,
            "X-Goog-FieldMask": (
                "places.id,"
                "places.displayName,"
                "places.formattedAddress,"
                "places.types,"
                "places.location"
            ),
        }

        body = {
            "textQuery": query,
            "pageSize": max_results,
            "includedType": "locality",
        }

        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(url, headers=headers, json=body)
            resp.raise_for_status()
            return resp.json()
        
    async def search_destination_autocomplete(
        self,
        query: str,
        max_results: int = 10,
    ) -> dict:
        url = f"{self.base_url}/places:autocomplete"

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.api_key,
        }

        body = {
            "input": query,
            "includedPrimaryTypes": ["locality"],
            "languageCode": "en",
        }

        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(url, headers=headers, json=body)
            resp.raise_for_status()
        return resp.json()
    
    async def autocomplete_places(
        self,
        query: str,
        max_results: int = 10,
    ) -> dict:
        url = f"{self.base_url}/places:autocomplete"

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.api_key,
        }

        body = {
            "input": query,
            "languageCode": "en",
        }

        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(url, headers=headers, json=body)
            resp.raise_for_status()
            return resp.json()


places_client = GooglePlacesClient()