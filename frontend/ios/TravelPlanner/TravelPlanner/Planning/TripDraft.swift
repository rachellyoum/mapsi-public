import Foundation
import SwiftUI

// MARK: - Must Visit Place Draft
struct MustVisitPlaceDraft: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let address: String?
    let lat: Double?
    let lng: Double?
    let rating: Double?
    let type: String?

    init(
        id: String,
        name: String,
        address: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        rating: Double? = nil,
        type: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.lat = lat
        self.lng = lng
        self.rating = rating
        self.type = type
    }
}

// MARK: - TripDraft (App state)
struct TripDraft: Codable, Equatable {
    var originAirport: String = ""
    var destinationCity: String = ""
    var destinationIATA: String = ""
    var destinationCountry: String = ""

    var startDate: Date? = nil
    var endDate: Date? = nil

    var travelersCount: Int = 1
    var budgetTotal: Double = 0

    /// ex) ["group:friends", "theme:shopping"]
    var preferences: [String] = []
    var mustVisitPlaces: [MustVisitPlaceDraft] = []
}

// MARK: - Draft Storage
protocol TripDraftStoring {
    func load() throws -> TripDraft?
    func save(_ draft: TripDraft) throws
    func clear() throws
}

final class UserDefaultsTripDraftStore: TripDraftStoring {
    private let ud = UserDefaults.standard
    private let userId: String

    private var key: String {
        "trip_draft_v1_\(userId)"
    }

    init(userId: String) {
        self.userId = userId
    }

    func load() throws -> TripDraft? {
        guard let data = ud.data(forKey: key) else { return nil }
        return try JSONDecoder.trip.decode(TripDraft.self, from: data)
    }

    func save(_ draft: TripDraft) throws {
        let data = try JSONEncoder.trip.encode(draft)
        ud.set(data, forKey: key)
    }

    func clear() throws {
        ud.removeObject(forKey: key)
    }
}

// MARK: - ViewModel
@MainActor
final class TripDraftViewModel: ObservableObject {
    @Published private(set) var draft: TripDraft

    @Published var displayedMonth: Date = Date()
    @Published var isSelectingEnd: Bool = false
    @Published var mustVisitPlaces: [MustVisitPlaceDraft] {
        didSet {
            var newDraft = draft
            newDraft.mustVisitPlaces = mustVisitPlaces
            draft = newDraft
            persist()
        }
    }

    private let store: TripDraftStoring
    private let tripService: TripService
    let userId: String

    init(
        userId: String,
        tripService: TripService = TripService(client: APIClient())
    ) {
        self.userId = userId
        self.store = UserDefaultsTripDraftStore(userId: userId)
        self.tripService = tripService

        let initialDraft: TripDraft
        if let loaded = try? store.load() {
            initialDraft = loaded
        } else {
            initialDraft = TripDraft()
        }

        self.draft = initialDraft
        self.mustVisitPlaces = initialDraft.mustVisitPlaces
    }

    // MARK: - Update helpers

    func setDates(start: Date?, end: Date?) {
        var newDraft = draft
        newDraft.startDate = start
        newDraft.endDate = end
        draft = newDraft
        persist()
    }
    
    func setDestination(city: String, iata: String, country: String) {
        var newDraft = draft
        newDraft.destinationCity = city
        newDraft.destinationIATA = iata
        newDraft.destinationCountry = country
        draft = newDraft
        persist()
    }
    
    func setMustVisitPlaces(_ places: [MustVisitPlaceDraft]) {
        mustVisitPlaces = places
    }

    func setOriginAirport(_ code: String) {
        var newDraft = draft
        newDraft.originAirport = code
        draft = newDraft
        persist()
    }

    func setTravelersCount(_ n: Int) {
        var newDraft = draft
        newDraft.travelersCount = max(1, n)
        draft = newDraft
        persist()
    }

    func setBudgetTotal(_ value: Double) {
        var newDraft = draft
        newDraft.budgetTotal = max(0, value)
        draft = newDraft
        persist()
    }

    func setPreference(key: String, value: String) {
        let prefix = "\(key):"
        var newDraft = draft
        newDraft.preferences.removeAll { $0.hasPrefix(prefix) }
        newDraft.preferences.append("\(prefix)\(value)")
        draft = newDraft
        persist()
    }

    func toggleTheme(_ theme: String) {
        let token = "theme:\(theme)"
        var newDraft = draft

        if newDraft.preferences.contains(token) {
            newDraft.preferences.removeAll { $0 == token }
        } else {
            newDraft.preferences.append(token)
        }

        draft = newDraft
        persist()
    }

    // MARK: - Persist
    func persist() {
        try? store.save(draft)
    }

    func resetDraft() {
        draft = TripDraft()
        try? store.clear()
    }

    // MARK: - Validation
    var isReadyToSubmit: Bool {
        guard !draft.originAirport.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !draft.destinationCity.isEmpty,
              !draft.destinationIATA.isEmpty,
              !draft.destinationCountry.isEmpty else { return false }
        guard let s = draft.startDate, let e = draft.endDate, s <= e else { return false }
        guard draft.travelersCount >= 1 else { return false }
        return true
    }

    // MARK: - Request Builder
    func makeCreateTripRequest(userId: String) throws -> CreateTripRequest {
        guard let s = draft.startDate, let e = draft.endDate else {
            throw TripDraftError.missingDates
        }

        var pace: String? = nil
        var themes: [String] = []

        for pref in draft.preferences {
            let parts = pref.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }

            let key = parts[0]
            let value = parts[1]

            if key == "pace" {
                pace = value
            } else if key == "theme" {
                themes.append(value)
            }
        }

        let startString = isoDate(s)
        let endString = isoDate(e)

        print("Trip request start_datetime:", startString)
        print("Trip request end_datetime:", endString)

        let mustVisit = draft.mustVisitPlaces.map {
            MustVisitPreference(
                place_id: $0.id,
                place_name: $0.name,
                lat: $0.lat,
                lng: $0.lng,
                address: $0.address,
                rating: $0.rating,
                type: $0.type
            )
        }

        let requestPreferences = CreateTripPreferences(
            pace: pace,
            themes: themes,
            mustVisit: mustVisit
        )

        print("MUST VISIT SENT:", mustVisit.map { $0.place_name })

        return CreateTripRequest(
            user_id: userId,
            origin_airport: draft.originAirport,
            destination_city: draft.destinationCity,
            destination_iata: draft.destinationIATA,
            destination_country: draft.destinationCountry,
            start_datetime: startString,
            end_datetime: endString,
            travelers_count: draft.travelersCount,
            budget_total: draft.budgetTotal,
            preferences: requestPreferences
        )
    }

    // MARK: - API
    func createTripDraft(userId: String, idToken: String) async throws -> CreateTripResponse {
        let req = try makeCreateTripRequest(userId: userId)
        return try await tripService.createTripDraft(payload: req, idToken: idToken)
    }

    func generateItinerary(tripId: String, idToken: String) async throws -> GenerateTripResponse {
        return try await tripService.generateItinerary(tripId: tripId, idToken: idToken)
    }

    // MARK: - Helpers
    private func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .autoupdatingCurrent
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone]
        return formatter.string(from: date)
    }
}

enum TripDraftError: Error {
    case missingDates
}

// MARK: - JSON Encoder/Decoder
extension JSONEncoder {
    static var trip: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var trip: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
