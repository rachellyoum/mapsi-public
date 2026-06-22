import Foundation

final class APIClient {
    
    enum APIError: LocalizedError {
        case invalidURL
        case badStatus(Int, Data)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL."
            case .badStatus(let code, let data):
                let body = String(data: data, encoding: .utf8) ?? "No response body"
                return "Request failed (\(code)): \(body)"
            case .decodingFailed:
                return "Failed to decode server response."
            }
        }
    }
    
    var baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "https://mapsi-backend-637742275322.us-west1.run.app/")!) {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }
    
    func get<T: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let base = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var components = URLComponents(url: base, resolvingAgainstBaseURL: true)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 300
        req.httpMethod = "GET"
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }

        print("GET URL:", url.absoluteString)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.badStatus(-1, data)
        }

        print("STATUS:", http.statusCode)
        print("RESPONSE BODY:", String(data: data, encoding: .utf8) ?? "nil")

        guard (200...299).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, data)
        }

        do {
            return try JSONDecoder.trip.decode(T.self, from: data)
        } catch {
            print("DECODING ERROR:", error)
            throw APIError.decodingFailed
        }
    }
    
    func post<T: Decodable, U: Encodable>(
        _ path: String,
        body: U,
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 300
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.httpBody = try JSONEncoder.trip.encode(body)

        print("POST URL:", url.absoluteString)
        print("HEADERS:", req.allHTTPHeaderFields ?? [:])

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.badStatus(-1, data)
        }

        print("STATUS:", http.statusCode)
        print("RESPONSE BODY:", String(data: data, encoding: .utf8) ?? "nil")

        guard (200...299).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, data)
        }

        do {
            return try JSONDecoder.trip.decode(T.self, from: data)
        } catch {
            print("DECODING ERROR:", error)
            throw APIError.decodingFailed
        }
    }
    func patch(
        _ path: String,
        headers: [String: String] = [:]
    ) async throws {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 300
        req.httpMethod = "PATCH"
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }

        print("PATCH URL:", url.absoluteString)
        print("HEADERS:", req.allHTTPHeaderFields ?? [:])

        let (data, resp) = try await session.data(for: req)

        guard let http = resp as? HTTPURLResponse else {
            throw APIError.badStatus(-1, data)
        }

        print("STATUS:", http.statusCode)
        print("RESPONSE BODY:", String(data: data, encoding: .utf8) ?? "nil")

        guard (200...299).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, data)
        }
    }
    func postRaw<U: Encodable>(
        _ path: String,
        body: U,
        headers: [String: String] = [:]
    ) async throws -> Data {

        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 300   // 친구 코드 👍
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }

        req.httpBody = try JSONEncoder.trip.encode(body)

        print("POST RAW URL:", url.absoluteString)
        print("HEADERS:", req.allHTTPHeaderFields ?? [:]) // 친구 코드 👍

        let (data, resp) = try await session.data(for: req) // 친구 코드 👍

        guard let http = resp as? HTTPURLResponse else {
            throw APIError.badStatus(-1, data)
        }

        print("STATUS:", http.statusCode)
        print("RAW BODY:", String(data: data, encoding: .utf8) ?? "nil") // 네 로그 👍

        guard (200...299).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, data)
        }

        return data
    }
    func delete(
        _ path: String,
        headers: [String: String] = [:]
    ) async throws {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 300
        req.httpMethod = "DELETE"
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }

        print("DELETE URL:", url.absoluteString)
        print("HEADERS:", req.allHTTPHeaderFields ?? [:])

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.badStatus(-1, data)
        }

        print("STATUS:", http.statusCode)
        print("RESPONSE BODY:", String(data: data, encoding: .utf8) ?? "nil")

        guard (200...299).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, data)
        }
    }
    
}

struct UserSearchResponse: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let email: String?
}

struct TripShareRequest: Encodable {
    let user_id: String
    let role: String
}

struct TripMemberResponse: Codable, Identifiable { //fix
    let id: String
    let user_id: String
    let role: String
    let name: String?
    let email: String?
    let avatarColorIndex: Int?
}

// MARK: - Request Models

struct MustVisitPreference: Encodable {
    let place_id: String?
    let place_name: String
    let lat: Double?
    let lng: Double?
    let address: String?
    let rating: Double?
    let type: String?
}

struct CreateTripPreferences: Encodable {
    let pace: String?
    let themes: [String]
    let mustVisit: [MustVisitPreference]
}

struct CreateTripRequest: Encodable {
    let user_id: String
    let origin_airport: String
    let destination_city: String
    let destination_iata: String
    let destination_country: String
    let start_datetime: String
    let end_datetime: String
    let travelers_count: Int
    let budget_total: Double
    let preferences: CreateTripPreferences
}
struct AddStopRequest: Encodable {
    let insert_position: Int
    let stop: AddStopBody
}

struct AddStopBody: Encodable {
    let place_id: String
    let place_name: String
    let activity: String
    let address: String?
    let lat: Double?
    let lng: Double?
    let type: String?
    let rating: Double?
}

struct DestinationSearchResult: Decodable, Identifiable, Hashable {
    var id: String { placeId ?? "\(city)-\(iata ?? "")-\(country)" }

    let placeId: String?
    let name: String?
    let displayName: String?
    let city: String
    let iata: String?
    let country: String
    let lat: Double?
    let lng: Double?
    let types: [String]?

    private enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name
        case displayName = "display_name"
        case city = "destination_city"
        case country = "destination_country"
        case iata = "destination_iata"
        case lat
        case lng
        case types
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        placeId = try container.decodeIfPresent(String.self, forKey: .placeId)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        let decodedCity = try container.decodeIfPresent(String.self, forKey: .city)
        let decodedName = try container.decodeIfPresent(String.self, forKey: .name)
        city = decodedCity ?? decodedName ?? ""
        country = try container.decodeIfPresent(String.self, forKey: .country) ?? ""
        iata = try container.decodeIfPresent(String.self, forKey: .iata)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        types = try container.decodeIfPresent([String].self, forKey: .types)
    }
}

struct PlaceLookupResponse: Decodable {
    let trip_id: String
    let query: String
    let query_used: String?
    let places: [PlaceSearchResult]
    let cached: Bool?
}

struct PlaceSearchResultsResponse: Decodable {
    let places: [PlaceSearchResult]

    private enum CodingKeys: String, CodingKey {
        case places
        case results
    }

    init(from decoder: Decoder) throws {
        if let array = try? [PlaceSearchResult](from: decoder) {
            self.places = array
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let places = try? container.decode([PlaceSearchResult].self, forKey: .places) {
            self.places = places
        } else if let results = try? container.decode([PlaceSearchResult].self, forKey: .results) {
            self.places = results
        } else {
            self.places = []
        }
    }
}

struct DestinationSearchResultsResponse: Decodable {
    let destinations: [DestinationSearchResult]

    private enum CodingKeys: String, CodingKey {
        case destinations
        case results
        case places
    }

    init(from decoder: Decoder) throws {
        if let array = try? [DestinationSearchResult](from: decoder) {
            self.destinations = array
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let destinations = try? container.decode([DestinationSearchResult].self, forKey: .destinations) {
            self.destinations = destinations
        } else if let results = try? container.decode([DestinationSearchResult].self, forKey: .results) {
            self.destinations = results
        } else if let places = try? container.decode([DestinationSearchResult].self, forKey: .places) {
            self.destinations = places
        } else {
            self.destinations = []
        }
    }
}

struct EmptyBody: Encodable {}

// MARK: - Response Models

struct CreateTripResponse: Decodable {
    let id: String
    let user_id: String
    let origin_airport: String
    let destination_city: String
    let destination_iata: String
    let destination_country: String
    let start_datetime: String?
    let end_datetime: String?
    let travelers_count: Int
    let budget_total: Double
    let preferences: TripPreferencesResponse?
    let itinerary_json: ItineraryPayload?
    let status: String
}

struct MustVisitPreferenceResponse: Codable, Hashable {
    let place_id: String?
    let place_name: String?
    let lat: Double?
    let lng: Double?
    let address: String?
    let rating: Double?
    let type: String?

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let name = try? singleValue.decode(String.self) {
            self.place_id = nil
            self.place_name = name
            self.lat = nil
            self.lng = nil
            self.address = nil
            self.rating = nil
            self.type = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.place_id = try container.decodeIfPresent(String.self, forKey: .place_id)
        self.place_name = try container.decodeIfPresent(String.self, forKey: .place_name)
        self.lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        self.lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
    }

    private enum CodingKeys: String, CodingKey {
        case place_id
        case place_name
        case lat
        case lng
        case address
        case rating
        case type
    }
}

struct TripPreferencesResponse: Codable {
    let pace: String?
    let themes: [String]?
    let mustVisit: [MustVisitPreferenceResponse]?
    let transportation: [String]?
}

struct GenerateTripResponse: Codable {
    let trip_id: String
    let itinerary: ItineraryPayload
    let cached: Bool
}

struct ItineraryPayload: Codable {
    let trip_summary: TripSummary
    let days: [TripDay]
    let tips: [String]

    private enum CodingKeys: String, CodingKey {
        case trip_summary
        case days
        case tips
    }

    init(trip_summary: TripSummary, days: [TripDay], tips: [String] = []) {
        self.trip_summary = trip_summary
        self.days = days
        self.tips = tips.isEmpty ? days.flatMap { $0.tips ?? [] } : tips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tripSummary = try container.decode(TripSummary.self, forKey: .trip_summary)
        let days = try container.decode([TripDay].self, forKey: .days)
        let tips = try container.decodeIfPresent([String].self, forKey: .tips) ?? days.flatMap { $0.tips ?? [] }

        self.trip_summary = tripSummary
        self.days = days
        self.tips = tips
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(trip_summary, forKey: .trip_summary)
        try container.encode(days, forKey: .days)
        try container.encode(tips, forKey: .tips)
    }
}

struct TripSummary: Codable { //fix
    let destination: String
    let days: Int?
    let vibe: String?
    let total_price_level: PriceLevelRange?
    let preferences: TripPreferencesResponse? = nil
}

struct TripDay: Codable, Identifiable {
    var id: Int { day }

    let day: Int
    let title: String
    let stops: [TripItem]
    let tips: [String]?
    let day_price_level: PriceLevelRange?

    var items: [TripItem] { stops }

    private enum CodingKeys: String, CodingKey {
        case day
        case title
        case stops
        case items
        case tips
        case day_price_level
    }

    init(day: Int, title: String, items: [TripItem], tips: [String]? = nil, day_price_level: PriceLevelRange? = nil) {
        self.day = day
        self.title = title
        self.stops = items
        self.tips = tips
        self.day_price_level = day_price_level
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Int.self, forKey: .day)
        title = try container.decode(String.self, forKey: .title)
        stops =
            try container.decodeIfPresent([TripItem].self, forKey: .stops)
            ?? container.decodeIfPresent([TripItem].self, forKey: .items)
            ?? []
        tips = try container.decodeIfPresent([String].self, forKey: .tips)
        day_price_level = try container.decodeIfPresent(PriceLevelRange.self, forKey: .day_price_level)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(title, forKey: .title)
        try container.encode(stops, forKey: .stops)
        try container.encodeIfPresent(tips, forKey: .tips)
        try container.encodeIfPresent(day_price_level, forKey: .day_price_level)
    }
}

struct TripItem: Codable, Identifiable {
    let id = UUID()
    let order: Int?
    let time_block: String?
    let place_name: String
    let lat: Double?
    let lng: Double?
    let type: String?
    let place_id: String?
    let opening_hours: String?
    let rating: Double?
    let activity: String
    let address: String?
    let price_level: Int?
    let stop_price_level: PriceLevelRange?
    let reviews: [PlaceReview]?
    let notes: String?
    let travel_from_previous: TravelFromPrevious?

    private enum CodingKeys: String, CodingKey {
        case order
        case time_block
        case place_name
        case lat
        case lng
        case type
        case place_id
        case opening_hours
        case rating
        case activity
        case address
        case price_level
        case stop_price_level
        case reviews
        case notes
        case travel_from_previous
    }

    init(
        order: Int?,
        time_block: String?,
        place_name: String,
        lat: Double?,
        lng: Double?,
        type: String?,
        place_id: String?,
        opening_hours: String?,
        rating: Double?,
        activity: String,
        address: String?,
        price_level: Int?,
        stop_price_level: PriceLevelRange? = nil,
        reviews: [PlaceReview]? = nil,
        notes: String?,
        travel_from_previous: TravelFromPrevious?
    ) {
        self.order = order
        self.time_block = time_block
        self.place_name = place_name
        self.lat = lat
        self.lng = lng
        self.type = type
        self.place_id = place_id
        self.opening_hours = opening_hours
        self.rating = rating
        self.activity = activity
        self.address = address
        self.price_level = price_level
        self.stop_price_level = stop_price_level
        self.reviews = reviews
        self.notes = notes
        self.travel_from_previous = travel_from_previous
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        order = try container.decodeIfPresent(Int.self, forKey: .order)
        time_block = try container.decodeIfPresent(String.self, forKey: .time_block)
        place_name = try container.decode(String.self, forKey: .place_name)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        place_id = try container.decodeIfPresent(String.self, forKey: .place_id)
        opening_hours = try container.decodeIfPresent(String.self, forKey: .opening_hours)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        activity = try container.decode(String.self, forKey: .activity)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        price_level = try container.decodeIfPresent(Int.self, forKey: .price_level)
        stop_price_level = try container.decodeIfPresent(PriceLevelRange.self, forKey: .stop_price_level)
        reviews = try container.decodeIfPresent([PlaceReview].self, forKey: .reviews)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        travel_from_previous = try container.decodeIfPresent(TravelFromPrevious.self, forKey: .travel_from_previous)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encodeIfPresent(time_block, forKey: .time_block)
        try container.encode(place_name, forKey: .place_name)
        try container.encodeIfPresent(lat, forKey: .lat)
        try container.encodeIfPresent(lng, forKey: .lng)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(place_id, forKey: .place_id)
        try container.encodeIfPresent(opening_hours, forKey: .opening_hours)
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encode(activity, forKey: .activity)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(price_level, forKey: .price_level)
        try container.encodeIfPresent(stop_price_level, forKey: .stop_price_level)
        try container.encodeIfPresent(reviews, forKey: .reviews)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(travel_from_previous, forKey: .travel_from_previous)
    }
}

struct PriceLevelRange: Codable, Hashable {
    let currency: String?
    let min: Double?
    let max: Double?
}

struct PlaceReview: Codable, Hashable {
    let rating: Double?
    let text: String?
    let publish_time: String?
    let relative_publish_time_description: String?
    let author: ReviewAuthor?
}

struct ReviewAuthor: Codable, Hashable {
    let display_name: String?
    let uri: String?
    let photo_uri: String?
}

struct TravelFromPrevious: Codable, Hashable {
    let recommended_mode: String?
    let recommended_duration_min: Double?
    let recommended_reason: String?
    let distance_meters: Double?
    let polyline: String?
    let options: [TravelOption]?
}

struct TravelOption: Codable, Hashable {
    let mode: String
    let available: Bool
    let duration_min: Double?
    let distance_meters: Double?
    let polyline: String?
}

struct ShareTripSuccessResponse: Decodable {
    let success: Bool?
    let message: String?
}

struct TripPlacesSearchResponse: Decodable {
    let trip_id: String
    let query_used: String
    let places: [PlaceSearchResult]
    let cached: Bool
}

struct PlaceSearchResult: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String?
    let rating: Double?
    let price_level: String?
    let types: [String]?
    let lat: Double?
    let lng: Double?
    let photo_url: String?
    
    init(
        id: String,
        name: String,
        address: String? = nil,
        rating: Double? = nil,
        price_level: String? = nil,
        types: [String]? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        photo_url: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.rating = rating
        self.price_level = price_level
        self.types = types
        self.lat = lat
        self.lng = lng
        self.photo_url = photo_url
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case placeId = "place_id"
        case name
        case placeName = "place_name"
        case displayName = "display_name"
        case address
        case formattedAddress = "formatted_address"
        case formattedAddressCamel = "formattedAddress"
        case destinationCity = "destination_city"
        case destinationCountry = "destination_country"
        case rating
        case price_level
        case types
        case lat
        case lng
        case photo_url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedId = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .placeId)
            ?? UUID().uuidString

        let decodedName = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .placeName)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
            ?? "Unknown Place"

        let decodedAddressValue = try container.decodeIfPresent(String.self, forKey: .address)
        let decodedFormattedAddress = try container.decodeIfPresent(String.self, forKey: .formattedAddress)
        let decodedFormattedAddressCamel = try container.decodeIfPresent(String.self, forKey: .formattedAddressCamel)
        let decodedDisplayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        let decodedDestinationCity = try container.decodeIfPresent(String.self, forKey: .destinationCity)
        let decodedDestinationCountry = try container.decodeIfPresent(String.self, forKey: .destinationCountry)

        let destinationSubtitle = [decodedDestinationCity, decodedDestinationCountry]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: ", ")

        let decodedAddress = decodedAddressValue
            ?? decodedFormattedAddress
            ?? decodedFormattedAddressCamel
            ?? decodedDisplayName
            ?? (destinationSubtitle.isEmpty ? nil : destinationSubtitle)

        id = decodedId
        name = decodedName

        if let decodedAddress,
           !decodedAddress.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty,
           decodedAddress != decodedName {
            address = decodedAddress
        } else {
            address = nil
        }

        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        price_level = Self.decodeFlexibleStringIfPresent(from: container, forKey: .price_level)
        types = try container.decodeIfPresent([String].self, forKey: .types)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        photo_url = try container.decodeIfPresent(String.self, forKey: .photo_url)
    }

    private static func decodeFlexibleStringIfPresent(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> String? {
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }

        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }

        return nil
    }
}

// MARK: - TripService

struct TripService {
    let client: APIClient

    func createTripDraft(
        payload: CreateTripRequest,
        idToken: String
    ) async throws -> CreateTripResponse {
        try await client.post(
            "trips",
            body: payload,
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }

    func fetchMyTrips(idToken: String) async throws -> [CreateTripResponse] {
        try await client.get(
            "trips",
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }
    func searchPlaces(
        query: String,
        city: String,
        country: String,
        idToken: String
    ) async throws -> [PlaceSearchResult] {
        let response: PlaceSearchResultsResponse = try await client.get(
            "mustvisitsearch",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "city", value: city),
                URLQueryItem(name: "country", value: country)
            ],
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )

        print("MUST VISIT SEARCH USING mustvisitsearch:", query, city, country, "COUNT:", response.places.count)
        return response.places
    }

    func searchPlaces(
        query: String,
        idToken: String
    ) async throws -> [PlaceSearchResult] {
        let response: PlaceSearchResultsResponse = try await client.get(
            "places/search",
            queryItems: [
                URLQueryItem(name: "q", value: query)
            ],
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )

        print("PLACE SEARCH USING places/search:", query, "COUNT:", response.places.count)
        return response.places
    }
    func searchDestinations(
        query: String,
        idToken: String
    ) async throws -> [DestinationSearchResult] {
        let response: DestinationSearchResultsResponse = try await client.get(
            "destinations/search",
            queryItems: [
                URLQueryItem(name: "q", value: query)
            ],
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )

        return response.destinations
    }

    func lookupTripPlaces(
        tripId: String,
        query: String,
        idToken: String
    ) async throws -> [PlaceSearchResult] {
        let response: PlaceLookupResponse = try await client.get(
            "trips/\(tripId)/places/lookup",
            queryItems: [
                URLQueryItem(name: "q", value: query)
            ],
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )

        print("PLACE LOOKUP ENDPOINT USED:", response.query_used ?? response.query, "COUNT:", response.places.count)
        return response.places
    }
    
    func generateItinerary(
        tripId: String,
        idToken: String
    ) async throws -> GenerateTripResponse {
        try await client.post(
            "trips/\(tripId)/itinerary/generate",
            body: EmptyBody(),
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }

    func deleteItinerary(
        tripId: String,
        idToken: String
    ) async throws {
        try await client.delete(
            "trips/\(tripId)/itinerary",
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }

    func searchUsers(query: String, idToken: String) async throws -> [UserSearchResponse] {
        try await client.get(
            "users/search",
            queryItems: [
                URLQueryItem(name: "q", value: query)
            ],
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }
    func fetchTripDetail(tripId: String, idToken: String) async throws -> CreateTripResponse {
        try await client.get(
            "trips/\(tripId)",
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }
    func addStop(
        tripId: String,
        day: Int,
        body: AddStopRequest,
        idToken: String
    ) async throws {
        let _: Data = try await client.postRaw(
            "trips/\(tripId)/itinerary/days/\(day)/stops",
            body: body,
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }
    func swapStops(
        tripId: String,
        day: Int,
        a: Int,
        b: Int,
        idToken: String
    ) async throws {
        try await client.patch(
            "trips/\(tripId)/itinerary/days/\(day)/stops/swap/\(a)/\(b)",
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }
    func deleteStop(
        tripId: String,
        day: Int,
        order: Int,
        idToken: String
    ) async throws {
        try await client.delete(
            "trips/\(tripId)/itinerary/days/\(day)/stops/\(order)",
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }

    func shareTrip(
        tripId: String,
        targetUserId: String,
        role: String,
        idToken: String
    ) async throws {
        let _: ShareTripSuccessResponse = try await client.post(
            "trips/\(tripId)/share",
            body: TripShareRequest(user_id: targetUserId, role: role),
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }

    func fetchTripMembers(
        tripId: String,
        idToken: String
    ) async throws -> [TripMemberResponse] {
        try await client.get(
            "trips/\(tripId)/members",
            headers: [
                "Authorization": "Bearer \(idToken)"
            ]
        )
    }
}
