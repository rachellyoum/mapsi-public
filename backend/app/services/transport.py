import asyncio
from app.services.routes import get_transport_options


async def attach_transport_to_itinerary_dict(itinerary: dict) -> dict:
    for day in itinerary.get("days", []):
        stops = day.get("stops", [])

        if not stops:
            continue

        # First stop has no travel from previous
        stops[0]["travel_from_previous"] = None

        tasks = []
        task_indices = []

        for i in range(1, len(stops)):
            prev = stops[i - 1]
            stop = stops[i]

            if (
                prev.get("lat") is None
                or prev.get("lng") is None
                or stop.get("lat") is None
                or stop.get("lng") is None
            ):
                stop["travel_from_previous"] = None
                continue

            tasks.append(
                get_transport_options(
                    origin=(prev["lat"], prev["lng"]),
                    destination=(stop["lat"], stop["lng"]),
                )
            )
            task_indices.append(i)

        if tasks:
            results = await asyncio.gather(*tasks, return_exceptions=True)

            for i, result in zip(task_indices, results):
                if isinstance(result, Exception):
                    stops[i]["travel_from_previous"] = None
                else:
                    stops[i]["travel_from_previous"] = result

    return itinerary