from __future__ import annotations

import time
from dataclasses import dataclass
import httpx

from app.core.config import settings


@dataclass
class AmadeusToken:
    access_token: str
    expires_at: float  # unix timestamp


class AmadeusClient:
    """
    Minimal Amadeus client:
    - fetches OAuth2 token (client credentials)
    - reuses token until expiry
    """
    def __init__(self) -> None:
        self.base_url = "https://test.api.amadeus.com"  # sandbox
        self._token: AmadeusToken | None = None

        if not settings.AMADEUS_CLIENT_ID or not settings.AMADEUS_CLIENT_SECRET:
            raise RuntimeError("AMADEUS_CLIENT_ID/AMADEUS_CLIENT_SECRET not set")


    async def _get_token(self) -> str:
        # reuse token if still valid (with small safety buffer)
        if self._token and time.time() < self._token.expires_at - 30:
            return self._token.access_token

        url = f"{self.base_url}/v1/security/oauth2/token"
        data = {
            "grant_type": "client_credentials",
            "client_id": settings.AMADEUS_CLIENT_ID,
            "client_secret": settings.AMADEUS_CLIENT_SECRET,
        }

        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(url, data=data)
            resp.raise_for_status()
            payload = resp.json()

        access_token = payload["access_token"]
        expires_in = payload.get("expires_in", 1800)
        self._token = AmadeusToken(access_token=access_token, expires_at=time.time() + float(expires_in))
        return access_token


    def _parse_time(self, iso: str) -> str:
        if "T" in iso:
            return iso.split("T")[1][:5]
        return iso

    def _parse_duration(self, raw: str) -> str:
        s = raw.replace("PT", "")
        hours, mins = 0, 0
        if "H" in s:
            parts = s.split("H")
            hours = int(parts[0])
            s = parts[1]
        if "M" in s:
            mins = int(s.replace("M", ""))
        if hours and mins:
            return f"{hours}h {mins}m"
        if hours:
            return f"{hours}h"
        return f"{mins}m"

    def _format_offers(self, data: dict) -> list[dict]:
        formatted = []

        for offer in data.get("data", []):
            itineraries = offer.get("itineraries", [])
            first_itinerary = itineraries[0] if itineraries else {}
            segments = first_itinerary.get("segments", [])
            first_seg = segments[0] if segments else {}
            last_seg = segments[-1] if segments else {}

            stops = sum(len(it["segments"]) - 1 for it in itineraries)
            price = float(offer["price"].get("grandTotal") or offer["price"]["total"])
            cabin = offer["travelerPricings"][0]["fareDetailsBySegment"][0]["cabin"]
            carrier = (offer.get("validatingAirlineCodes") or [first_seg.get("carrierCode", "")])[0]
            duration = self._parse_duration(first_itinerary.get("duration", ""))

            formatted.append({
                 "id":             offer["id"],
                "airline":        carrier,
                "departure_code": first_seg.get("departure", {}).get("iataCode", ""),
                "arrival_code":   last_seg.get("arrival", {}).get("iataCode", ""),
                "departure_time": self._parse_time(first_seg.get("departure", {}).get("at", "")),
                "arrival_time":   self._parse_time(last_seg.get("arrival", {}).get("at", "")),
                "duration":       duration,
                "price":          price,
                "stops":          stops,
                "cabin":          cabin,
            })

        return formatted
    

    def _sort_formatted(self, offers: list[dict]) -> list[dict]:
        return sorted(offers, key=lambda x: (x["stops"], x["price"]))
    
    async def flight_offers_search(
        self,
        origin: str,
        destination: str,
        return_date: str | None = None,
        adults: int = 1,
        currency: str = "CAD",
        max_results: int = 20,
         ) -> list[dict]:
        token = await self._get_token()

        params = {
            "originLocationCode": origin,
            "destinationLocationCode": destination,
            "departureDate": departure_date,
            "adults": adults,
            "currencyCode": currency,
            "max": max_results,
        }
        if return_date:
            params["returnDate"] = return_date

        url = f"{self.base_url}/v2/shopping/flight-offers"
        headers = {"Authorization": f"Bearer {token}"}

        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.get(url, params=params, headers=headers)
            resp.raise_for_status()
            data = resp.json()

            offers = self._format_offers(data)
            offers = self._sort_formatted(offers)
            return offers


    async def airport_autocomplete(self, keyword: str, max_results: int = 10) -> dict:
        token = await self._get_token()
        keyword = keyword.upper()

        params = {
            "keyword": keyword,
            "subType": ["AIRPORT", "CITY"],
            "max": max_results,
        }

        url = f"{self.base_url}/v1/reference-data/locations"
        headers = {"Authorization": f"Bearer {token}"}

        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.get(url, params=params, headers=headers)
            resp.raise_for_status()
            return resp.json()

amadeus_client = AmadeusClient()

"""
from __future__ import annotations

from datetime import datetime
from dataclasses import dataclass
import csv
import re
import time

import httpx
import pytz
from timezonefinder import TimezoneFinder

from app.core.config import settings


@dataclass
class AmadeusToken:
    access_token: str
    expires_at: float  # unix timestamp


def extract_iata_code(value: str | None) -> str | None:
    if not value:
        return None

    match = re.search(r"\(([A-Z]{3})\)", value)
    if match:
        return match.group(1)

    value = value.strip().upper()

    if len(value) == 3 and value.isalpha():
        return value

    return None


class AmadeusClient:
    
    Minimal Amadeus client:
    - fetches OAuth2 token (client credentials)
    - reuses token until expiry
    

    def __init__(self) -> None:
        self.base_url = "https://test.api.amadeus.com"  # sandbox
        self._token: AmadeusToken | None = None

        if not settings.AMADEUS_CLIENT_ID or not settings.AMADEUS_CLIENT_SECRET:
            raise RuntimeError("AMADEUS_CLIENT_ID/AMADEUS_CLIENT_SECRET not set")

        self._airports: dict[str, dict] = {}
        with open("app/data/airports.csv", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                iata = row["iata_code"]
                if iata:
                    self._airports[iata.upper()] = {
                        "lat": float(row["latitude_deg"]),
                        "lon": float(row["longitude_deg"]),
                    }

        self.tf = TimezoneFinder()
        self._airline_cache: dict[str, str] = {}

    async def _get_token(self) -> str:
        if self._token and time.time() < self._token.expires_at - 30:
            return self._token.access_token

        url = f"{self.base_url}/v1/security/oauth2/token"
        data = {
            "grant_type": "client_credentials",
            "client_id": settings.AMADEUS_CLIENT_ID,
            "client_secret": settings.AMADEUS_CLIENT_SECRET,
        }

        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.post(url, data=data)
            resp.raise_for_status()
            payload = resp.json()

        access_token = payload["access_token"]
        expires_in = payload.get("expires_in", 1800)
        self._token = AmadeusToken(
            access_token=access_token,
            expires_at=time.time() + float(expires_in),
        )
        return access_token

    async def _get_airlines(self, codes: set[str]) -> dict[str, str]:
        token = await self._get_token()

        missing = [c for c in codes if c and c not in self._airline_cache]
        if not missing:
            return {c: self._airline_cache.get(c, c) for c in codes}

        url = f"{self.base_url}/v1/reference-data/airlines"
        headers = {"Authorization": f"Bearer {token}"}

        try:
            async with httpx.AsyncClient(timeout=20) as client:
                resp = await client.get(
                    url,
                    params={"airlineCodes": ",".join(missing)},
                    headers=headers,
                )
                print("airlines lookup status:", resp.status_code)
                print("airlines lookup body:", resp.text)
                resp.raise_for_status()
                data = resp.json()

            for item in data.get("data", []):
                code = item.get("iataCode")
                name = item.get("businessName") or item.get("commonName")
                if code and name:
                    self._airline_cache[code] = name

        except Exception as e:
            print("⚠️ airline lookup failed:", repr(e))

        for c in missing:
            self._airline_cache.setdefault(c, c)

        return {c: self._airline_cache.get(c, c) for c in codes}

    def _get_timezone(self, iata: str) -> str:
        code = extract_iata_code(iata)
        if not code:
            raise ValueError(f"Invalid IATA code: {iata}")

        airport = self._airports.get(code.upper())
        if not airport:
            raise ValueError(f"Unknown IATA code: {iata}")

        tz = self.tf.timezone_at(
            lat=airport["lat"],
            lng=airport["lon"],
        )

        if not tz:
            raise ValueError(f"Could not resolve timezone for {iata}")

        return tz

    def _localize_departure_date(self, origin: str, departure_date: str) -> datetime:
        tz_str = self._get_timezone(origin)
        tz = pytz.timezone(tz_str)

        naive_dt = datetime.fromisoformat(departure_date)
        local_dt = tz.localize(naive_dt)

        return local_dt

    def _parse_time(self, iso: str) -> str:
        if "T" in iso:
            return iso.split("T")[1][:5]
        return iso

    def _parse_duration(self, raw: str) -> str:
        s = raw.replace("PT", "")
        hours, mins = 0, 0

        if "H" in s:
            parts = s.split("H")
            hours = int(parts[0]) if parts[0].isdigit() else 0
            s = parts[1]

        if "M" in s:
            mins_str = s.replace("M", "")
            mins = int(mins_str) if mins_str.isdigit() else 0

        if hours and mins:
            return f"{hours}h {mins}m"
        if hours:
            return f"{hours}h"
        return f"{mins}m"

    def _format_offers(self, data: dict, airlines_map: dict[str, str]) -> list[dict]:
        formatted: list[dict] = []

        for offer in data.get("data", []):
            try:
                itineraries = offer.get("itineraries", [])
                if not itineraries:
                    print("⚠️ skipping offer: no itineraries")
                    continue

                first_itinerary = itineraries[0]
                segments = first_itinerary.get("segments", [])
                if not segments:
                    print("⚠️ skipping offer: no segments")
                    continue

                first_seg = segments[0]
                last_seg = segments[-1]

                stops = sum(
                    max(len(it.get("segments", [])) - 1, 0)
                    for it in itineraries
                )

                price_info = offer.get("price", {})
                raw_price = price_info.get("grandTotal") or price_info.get("total")
                if raw_price is None:
                    print("⚠️ skipping offer: missing price", offer)
                    continue

                try:
                    price = float(raw_price)
                except (TypeError, ValueError):
                    print("⚠️ skipping offer: invalid price", raw_price)
                    continue

                traveler_pricings = offer.get("travelerPricings", [])
                fare_details = []
                if traveler_pricings:
                    fare_details = traveler_pricings[0].get("fareDetailsBySegment", [])

                cabin = ""
                if fare_details:
                    cabin = fare_details[0].get("cabin", "")

                validating_codes = offer.get("validatingAirlineCodes") or []
                carrier_code = validating_codes[0] if validating_codes else first_seg.get("carrierCode", "")
                airline_name = airlines_map.get(carrier_code, carrier_code)

                duration = self._parse_duration(first_itinerary.get("duration", ""))

                formatted.append({
                    "id": offer.get("id", ""),
                    "airline": {
                        "code": carrier_code,
                        "name": airline_name,
                    },
                    "departure_code": first_seg.get("departure", {}).get("iataCode", ""),
                    "arrival_code": last_seg.get("arrival", {}).get("iataCode", ""),
                    "departure_time": self._parse_time(first_seg.get("departure", {}).get("at", "")),
                    "arrival_time": self._parse_time(last_seg.get("arrival", {}).get("at", "")),
                    "duration": duration,
                    "price": price,
                    "stops": stops,
                    "cabin": cabin,
                })

            except Exception as e:
                print("❌ _format_offers skipping malformed offer:", repr(e))
                print("❌ bad offer payload:", offer)
                continue

        return formatted

    def _sort_formatted(self, offers: list[dict]) -> list[dict]:
        return sorted(offers, key=lambda x: (x["stops"], x["price"]))

    async def flight_offers_search(
        self,
        origin: str,
        destination: str,
        departure_date: str,
        return_date: str | None = None,
        adults: int = 1,
        currency: str = "CAD",
        max_results: int = 20,
    ) -> list[dict]:
        token = await self._get_token()

        origin_code = extract_iata_code(origin)
        destination_code = extract_iata_code(destination)

        if not origin_code:
            raise ValueError(f"Invalid origin code: {origin}")
        if not destination_code:
            raise ValueError(f"Invalid destination code: {destination}")

        local_dep_dt = self._localize_departure_date(origin_code, departure_date)

        params = {
            "originLocationCode": origin_code,
            "destinationLocationCode": destination_code,
            "departureDate": local_dep_dt.date().isoformat(),
            "adults": adults,
            "currencyCode": currency,
            "max": max_results,
        }
        if return_date:
            params["returnDate"] = return_date

        print("origin:", origin)
        print("destination:", destination)
        print("parsed origin:", origin_code)
        print("parsed destination:", destination_code)
        print("departure_date:", departure_date)
        print("return_date:", return_date)

        url = f"{self.base_url}/v2/shopping/flight-offers"
        headers = {"Authorization": f"Bearer {token}"}

        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.get(url, params=params, headers=headers)

            print("flight-offers params:", params)
            print("flight-offers status:", resp.status_code)
            print("flight-offers headers:", dict(resp.headers))
            print("flight-offers content length:", len(resp.content))
            print("flight-offers raw bytes:", resp.content[:500])

            try:
                print("flight-offers json:", resp.json())
            except Exception as e:
                print("flight-offers json decode failed:", repr(e))
                print("flight-offers text:", repr(resp.text))

            if resp.status_code >= 400 and return_date:
                print("⚠️ retrying without returnDate")

                fallback_params = dict(params)
                fallback_params.pop("returnDate", None)

                resp = await client.get(url, params=fallback_params, headers=headers)
                print("fallback params:", fallback_params)
                print("fallback status:", resp.status_code)
                print("fallback body:", resp.text)

            if resp.status_code >= 400:
                print("❌ Amadeus error:", resp.text)
                raise RuntimeError(
                    f"Amadeus flight-offers failed: {resp.status_code}: {resp.text}"
                )

            data = resp.json()

        print("offers count:", len(data.get("data", [])))
        print("sample offer:", data.get("data", [None])[0])

        codes = set()
        for offer in data.get("data", []):
            carrier = offer.get("validatingAirlineCodes") or []
            if carrier:
                codes.add(carrier[0])
            else:
                itineraries = offer.get("itineraries", [])
                if itineraries:
                    segs = itineraries[0].get("segments", [])
                    if segs:
                        code = segs[0].get("carrierCode")
                        if code:
                            codes.add(code)

        airlines_map = await self._get_airlines(codes)

        offers = self._format_offers(data, airlines_map)
        offers = self._sort_formatted(offers)

        print("formatted offers count:", len(offers))

        return offers

    async def airport_autocomplete(self, keyword: str, max_results: int = 10) -> dict:
        token = await self._get_token()
        keyword = keyword.upper()

        params = {
            "keyword": keyword,
            "subType": ["AIRPORT", "CITY"],
            "max": max_results,
        }

        url = f"{self.base_url}/v1/reference-data/locations"
        headers = {"Authorization": f"Bearer {token}"}

        try:
            async with httpx.AsyncClient(timeout=20) as client:
                resp = await client.get(url, params=params, headers=headers)
                print("airport autocomplete status:", resp.status_code)
                print("airport autocomplete body:", resp.text)
                resp.raise_for_status()
                data = resp.json()

        except httpx.HTTPStatusError as e:
            print("❌ Amadeus error:", {
                "url": str(e.request.url),
                "status": e.response.status_code,
                "body": e.response.text,
            })
            raise RuntimeError("Amadeus airport autocomplete failed") from e

        except httpx.RequestError as e:
            print("❌ Network error:", str(e))
            raise RuntimeError("Flight provider unreachable") from e

        return data


amadeus_client = AmadeusClient()
"""