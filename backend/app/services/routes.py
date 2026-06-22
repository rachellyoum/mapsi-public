import asyncio
import httpx
from app.core.config import settings


class GoogleRoutesClient:
    def __init__(self) -> None:
        if not settings.GOOGLE_MAPS_API_KEY:
            raise RuntimeError("GOOGLE_MAPS_API_KEY not set")

        self.base_url = "https://routes.googleapis.com"
        self.api_key = settings.GOOGLE_MAPS_API_KEY
        self.client = httpx.AsyncClient(timeout=20)

    async def compute_route(
        self,
        origin: tuple[float, float],
        destination: tuple[float, float],
        travel_mode: str = "DRIVE",
    ) -> dict:
        url = f"{self.base_url}/directions/v2:computeRoutes"

        headers = {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": self.api_key,
            "X-Goog-FieldMask": (
                "routes.duration,"
                "routes.distanceMeters,"
                "routes.polyline.encodedPolyline"
            ),
        }

        body = {
            "origin": {
                "location": {
                    "latLng": {
                        "latitude": origin[0],
                        "longitude": origin[1],
                    }
                }
            },
            "destination": {
                "location": {
                    "latLng": {
                        "latitude": destination[0],
                        "longitude": destination[1],
                    }
                }
            },
            "travelMode": travel_mode,
        }

        if travel_mode == "DRIVE":
            body["routingPreference"] = "TRAFFIC_AWARE"

        resp = await self.client.post(url, headers=headers, json=body)
        resp.raise_for_status()
        return resp.json()


routes_client = GoogleRoutesClient()


def parse_duration_to_minutes(duration_str: str | None) -> int | None:
    if not duration_str or not duration_str.endswith("s"):
        return None

    seconds = int(float(duration_str[:-1]))
    return max(1, round(seconds / 60))


async def get_route_option(
    origin: tuple[float, float],
    destination: tuple[float, float],
    mode: str,
) -> dict:
    try:
        data = await routes_client.compute_route(
            origin=origin,
            destination=destination,
            travel_mode=mode,
        )

        routes = data.get("routes", [])
        if not routes:
            return {
                "mode": mode,
                "available": False,
                "reason_unavailable": "No route returned",
            }

        route = routes[0]
        duration_str = route.get("duration")
        duration_min = parse_duration_to_minutes(duration_str)

        if duration_min is None:
            return {
                "mode": mode,
                "available": False,
                "reason_unavailable": "Missing duration",
            }

        return {
            "mode": mode,
            "available": True,
            "duration_min": duration_min,
            "distance_meters": route.get("distanceMeters"),
            "polyline": route.get("polyline", {}).get("encodedPolyline"),
        }

    except Exception as e:
        return {
            "mode": mode,
            "available": False,
            "reason_unavailable": str(e),
        }


def pick_recommended_mode(options: list[dict]) -> dict | None:
    by_mode = {
        option["mode"]: option
        for option in options
        if option.get("available") and option.get("duration_min") is not None
    }

    walk = by_mode.get("WALK")
    transit = by_mode.get("TRANSIT")
    drive = by_mode.get("DRIVE")

    # Rule 1: recommend walking if under 20 minutes
    if walk and walk["duration_min"] < 20:
        return {
            **walk,
            "reason": "Walking is under 20 minutes.",
        }

    # Rule 2: otherwise compare transit vs driving
    # Recommend transit if it is faster than driving,
    # or no more than 15 minutes slower than driving.
    if transit and drive:
        if transit["duration_min"] <= drive["duration_min"] + 15:
            return {
                **transit,
                "reason": "Transit is within 15 minutes of driving.",
            }
        return {
            **drive,
            "reason": "Driving is significantly faster than transit.",
        }

    # Rule 3: fallback if only one exists
    if transit:
        return {
            **transit,
            "reason": "Transit is the best available option.",
        }

    if drive:
        return {
            **drive,
            "reason": "Driving is the best available option.",
        }

    # Rule 4: final fallback to any available mode
    available = [
        option for option in options
        if option.get("available") and option.get("duration_min") is not None
    ]
    if not available:
        return None

    best = min(available, key=lambda x: x["duration_min"])
    return {
        **best,
        "reason": "Fastest available option.",
    }


async def get_transport_options(
    origin: tuple[float, float],
    destination: tuple[float, float],
) -> dict:
    modes = ["DRIVE", "TRANSIT", "WALK"]

    options = await asyncio.gather(
        *(get_route_option(origin, destination, mode) for mode in modes),
        return_exceptions=True,
    )

    cleaned_options = []
    for mode, option in zip(modes, options):
        if isinstance(option, Exception):
            cleaned_options.append({
                "mode": mode,
                "available": False,
                "reason_unavailable": str(option),
            })
        else:
            cleaned_options.append(option)

    recommended = pick_recommended_mode(cleaned_options)

    if not recommended:
        return {
            "recommended_mode": None,
            "recommended_duration_min": None,
            "recommended_reason": "No route available",
            "distance_meters": None,
            "polyline": None,
            "options": cleaned_options,
        }

    return {
        "recommended_mode": recommended["mode"],
        "recommended_duration_min": recommended["duration_min"],
        "recommended_reason": recommended.get("reason"),
        "distance_meters": recommended.get("distance_meters"),
        "polyline": recommended.get("polyline"),
        "options": cleaned_options,
    }