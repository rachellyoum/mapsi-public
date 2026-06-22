from typing import Dict

# This should be populated at startup (from your CSV loader)
# Example structure:
# AIRPORTS = {
#     "YVR": {"lat": 49.1939, "lon": -123.1844, "tz": "America/Vancouver"},
#     ...
# }
AIRPORTS: Dict[str, Dict[str, str]] = {}


def get_timezone(iata: str) -> str:
    """
    Returns the IANA timezone string for a given IATA airport code.

    Raises:
        ValueError: if the IATA code is invalid or timezone is missing.
    """
    if not iata:
        raise ValueError("IATA code is required")

    iata = iata.upper()

    airport = AIRPORTS.get(iata)
    if not airport:
        raise ValueError(f"Unknown IATA code: {iata}")

    tz = airport.get("tz")
    if not tz or tz == "\\N":
        raise ValueError(f"Timezone not found for IATA code: {iata}")

    return tz