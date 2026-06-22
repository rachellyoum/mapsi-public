

import Foundation

// MARK: - UI Enums

enum CabinClass: String, CaseIterable, Hashable {
    case economy  = "Economy"
    case business = "Prestige"
    case first    = "First"
}

enum TripType: String, CaseIterable, Hashable {
    case roundTrip = "Round trip"
    case oneWay    = "One-way"
    case multiCity = "Multi-city"
}

// MARK: - UI Flight Model

struct Airline: Hashable, Decodable {
    let code: String
    let name: String
}

struct Flight: Identifiable, Hashable, Decodable {
    let id: String
    let airline: Airline
    let departureCode: String
    let arrivalCode: String
    let departureTime: String
    let arrivalTime: String
    let duration: String
    let price: Double
    let stops: Int
    let cabin: String?

    var priceFormatted: String { String(format: "$%.0f", price) }
    var stopsText: String {
        stops == 0 ? "Nonstop" : "\(stops) stop\(stops > 1 ? "s" : "")"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case airline
        case departureCode = "departure_code"
        case arrivalCode   = "arrival_code"
        case departureTime = "departure_time"
        case arrivalTime   = "arrival_time"
        case duration
        case price
        case stops
        case cabin
    }
}

// MARK: - Airport Autocomplete

struct AirportResult: Decodable, Identifiable, Hashable {
    let iata: String
    let name: String
    let city: String?
    let country: String?

    var id: String { iata }
    var displayLine2: String {
        [city, country].compactMap { $0 }.joined(separator: ", ")
    }
}
extension AirportResult {
    var displayTitle: String {
        "\(city ?? name) (\(iata))"
    }

    var displaySubtitle: String {
        name
    }
}

// MARK: - Amadeus Raw Response Models
// 백엔드: { "trip_id": "...", "amadeus": { "meta": {...}, "data": [ flight-offer, ... ] } }

struct FlightSearchResponse: Decodable {
    let trip_id: String?
    let flights: [Flight]
    
    struct FlightsWrapper: Decodable {
        let data: [Flight]
    }
}

struct AmadeusPayload: Decodable {
    let meta: AmadeusMeta?
    let data: [AmadeusOffer]?
}

struct AmadeusMeta: Decodable {
    let count: Int?
}

struct AmadeusOffer: Decodable {
    let id: String
    let itineraries: [AmadeusItinerary]
    let price: AmadeusPrice
    let validatingAirlineCodes: [String]?
}

struct AmadeusItinerary: Decodable {
    let duration: String        // "PT5H10M"
    let segments: [AmadeusSegment]
}

struct AmadeusSegment: Decodable {
    let departure: AmadeusEndpoint
    let arrival: AmadeusEndpoint
    let carrierCode: String
    let numberOfStops: Int?
}

struct AmadeusEndpoint: Decodable {
    let iataCode: String
    let at: String              // "2026-03-24T11:40:00"
}

struct AmadeusPrice: Decodable {
    let total: String
    let grandTotal: String?
    let currency: String?
}

// MARK: - AmadeusOffer → Flight

extension AmadeusOffer {
    func toFlight() -> Flight? {
        guard let itinerary = itineraries.first,
              let firstSeg  = itinerary.segments.first,
              let lastSeg   = itinerary.segments.last
        else { return nil }

        let carrierCode = validatingAirlineCodes?.first ?? firstSeg.carrierCode
        let price       = Double(self.price.grandTotal ?? self.price.total) ?? 0
        let stops       = itinerary.segments.count - 1

        return Flight(
            id:            id,
            airline:       Airline(code: carrierCode, name: airlineName(for: carrierCode)),
            departureCode: firstSeg.departure.iataCode,
            arrivalCode:   lastSeg.arrival.iataCode,
            departureTime: parseTime(firstSeg.departure.at),
            arrivalTime:   parseTime(lastSeg.arrival.at),
            duration:      parseDuration(itinerary.duration),
            price:         price,
            stops:         stops,
            cabin:         nil
        )
    }

    private func parseTime(_ iso: String) -> String {
        guard let tIdx = iso.firstIndex(of: "T") else { return iso }
        return String(iso[iso.index(after: tIdx)...].prefix(5))
    }

    private func parseDuration(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "PT", with: "")
        var hours = 0, mins = 0
        if let r = s.range(of: "H") {
            hours = Int(s[s.startIndex..<r.lowerBound]) ?? 0
            s = String(s[r.upperBound...])
        }
        if let r = s.range(of: "M") {
            mins = Int(s[s.startIndex..<r.lowerBound]) ?? 0
        }
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }

    private func airlineName(for code: String) -> String {
        let map: [String: String] = [
            "AC": "Air Canada",         "WS": "WestJet",
            "DL": "Delta",              "UA": "United",
            "AA": "American",           "WN": "Southwest",
            "LH": "Lufthansa",          "BA": "British Airways",
            "AF": "Air France",         "KL": "KLM",
            "EK": "Emirates",           "QR": "Qatar Airways",
            "SQ": "Singapore Airlines", "CX": "Cathay Pacific",
            "NH": "ANA",                "JL": "Japan Airlines",
            "TK": "Turkish Airlines",   "B6": "JetBlue",
            "F9": "Frontier",           "NK": "Spirit",
            "AS": "Alaska Airlines",    "HA": "Hawaiian Airlines",
            "AM": "Aeromexico",         "MX": "Mexicana",
            "AC": "Air Canada",         "TS": "Air Transat",
        ]
        return map[code.uppercased()] ?? code
    }
}

// MARK: - FlightService

struct FlightService {
    let client: APIClient

    // GET /airports/search?q=...
    func searchAirports(query: String, idToken: String) async throws -> [AirportResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await client.get(
            "airports/search",
            queryItems: [URLQueryItem(name: "q", value: query)],
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }

    // POST /trips
    func createTrip(
        from: String,
        to: String,
        startDate: String,
        endDate: String?,
        travelers: Int,
        cabin: String,
        idToken: String
    ) async throws -> CreateTripResponse {
        let payload = CreateTripRequest(
            user_id: "me",
            origin_airport: from,
            destination_city: to,
            destination_iata: to,
            destination_country: "",
            start_datetime: startDate,
            end_datetime: endDate ?? startDate,
            travelers_count: travelers,
            budget_total: 0,
            preferences: CreateTripPreferences(
                pace: nil,
                themes: [],
                mustVisit: []
            )
        )
        return try await client.post(
            "trips",
            body: payload,
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }

    // POST /trips/{trip_id}/flights/search
    func searchFlights(tripId: String, idToken: String) async throws -> [Flight] {
        let data = try await client.postRaw(
            "trips/\(tripId)/flights/search",
            body: EmptyBody(),
            headers: ["Authorization": "Bearer \(idToken)"]
        )

        let decoder = JSONDecoder()

        // ✅ 1. wrapper 형태
        if let r = try? decoder.decode(FlightSearchResponse.self, from: data) {
            print("✅ decoded wrapper flights:", r.flights.count)
            return r.flights
        }

        // ✅ 2. array 바로 오는 경우 (이거 추가!!)
        if let flights = try? decoder.decode([Flight].self, from: data) {
            print("✅ decoded array flights:", flights.count)
            return flights
        }

        // ❗️ 디버깅
        let raw = String(data: data, encoding: .utf8) ?? "unreadable"
        print("❌ Decode failed. RAW RESPONSE:\n", raw)

        throw NSError(
            domain: "FlightService",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Decode failed"]
        )
    }
}
