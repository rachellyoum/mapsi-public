
import Foundation
import FirebaseAuth
import Combine
 
@MainActor
class FlightViewModel: ObservableObject {
 
    private let service = FlightService(client: APIClient())
 
    // MARK: - Search form
    @Published var tripType: TripType = .roundTrip
    @Published var fromCode = ""        // 선택된 IATA 코드 e.g. "YVR"
    @Published var toCode   = ""        // 선택된 IATA 코드 e.g. "JFK"
    @Published var fromText = ""        // 입력 텍스트 (자동완성용)
    @Published var toText   = ""        // 입력 텍스트 (자동완성용)
 
    @Published var departureDate = Date()
    @Published var returnDate    = Date()
    @Published var travelers     = 1
    @Published var cabinClass: CabinClass = .economy
 
    // MARK: - Autocomplete
    @Published var fromSuggestions: [AirportResult] = []
    @Published var toSuggestions:   [AirportResult] = []
    @Published var showFromSuggestions = false
    @Published var showToSuggestions   = false
 
    // MARK: - Results
    @Published var flights: [Flight] = []
    @Published var isLoading  = false
    @Published var errorMessage: String?
    @Published var showResults = false
    @Published private(set) var isSearching = false
 
    private var fromSearchTask: Task<Void, Never>?
    private var toSearchTask:   Task<Void, Never>?
 
    private let apiFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
 
    // MARK: - Display helpers
    var departureDateDisplay: String {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"; return f.string(from: departureDate)
    }
    var returnDateDisplay: String {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"; return f.string(from: returnDate)
    }
    var travelersDisplay: String {
        "\(travelers) Traveler\(travelers > 1 ? "s" : "")"
    }
    // 드롭다운 선택 시 Code, 직접 타이핑 시 Text를 fallback으로
    var effectiveFrom: String { fromCode.isEmpty ? fromText.trimmingCharacters(in: .whitespaces) : fromCode }
    var effectiveTo:   String { toCode.isEmpty   ? toText.trimmingCharacters(in: .whitespaces)   : toCode   }
 
    var isSearchEnabled: Bool {
        !effectiveFrom.isEmpty && !effectiveTo.isEmpty
    }
 
    func swapCities() {
        swap(&fromCode, &toCode)
        swap(&fromText, &toText)
    }
    func incrementTravelers() { if travelers < 9 { travelers += 1 } }
    func decrementTravelers() { if travelers > 1 { travelers -= 1 } }
 
    // MARK: - Autocomplete: From
 
    func onFromTextChanged(_ text: String) {
        fromCode = ""
        fromSearchTask?.cancel()
        guard text.count >= 2 else {
            fromSuggestions = []
            showFromSuggestions = false
            return
        }
        fromSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // 350ms debounce
            if Task.isCancelled { return }
            await fetchAirports(query: text, isFrom: true)
        }
    }

    func onToTextChanged(_ text: String) {
        toCode = ""
        toSearchTask?.cancel()
        guard text.count >= 2 else {
            toSuggestions = []
            showToSuggestions = false
            return
        }
        toSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await fetchAirports(query: text, isFrom: false)
        }
    }
 
    func selectFrom(_ airport: AirportResult) {
        fromCode = airport.iata
        fromText = airport.displayTitle
        fromSuggestions = []
        showFromSuggestions = false
    }
 
    func selectTo(_ airport: AirportResult) {
        toCode = airport.iata
        toText = airport.displayTitle
        toSuggestions = []
        showToSuggestions = false
    }
 
    private func fetchAirports(query: String, isFrom: Bool) async {
        guard !Task.isCancelled else { return }
        do {
            let token = try await fetchFirebaseToken()
            guard !Task.isCancelled else { return }
            var results = try await service.searchAirports(query: query, idToken: token)

            // ❗️ 결과 없으면 로컬 fallback
            if results.isEmpty {
                results = localAirportSearch(query: query)
            }
            guard !Task.isCancelled else { return }
            print("🔍 Airport search '\(query)': \(results.count) results")
            let ranked = rankAirports(results, query: query)

            if isFrom {
                fromSuggestions = ranked
                showFromSuggestions = !ranked.isEmpty
            } else {
                toSuggestions = ranked
                showToSuggestions = !ranked.isEmpty
            }
        } catch is CancellationError {
            // silently ignore — user kept typing
        } catch {
            print("❌ Airport search failed: \(error.localizedDescription)")
        }
    }
    // MARK: - Ranking (⭐️ 추가)

    private func rankAirports(_ results: [AirportResult], query: String) -> [AirportResult] {
        let q = query.lowercased()

        return results.sorted { a, b in
            score(a, q) > score(b, q)
        }
    }
    private func localAirportSearch(query: String) -> [AirportResult] {
        let q = query.lowercased()

        let all = [
            AirportResult(iata: "YVR", name: "Vancouver International Airport", city: "Vancouver", country: "Canada"),
            AirportResult(iata: "JFK", name: "John F Kennedy International Airport", city: "New York", country: "USA"),
            AirportResult(iata: "EWR", name: "Newark Liberty International Airport", city: "Newark", country: "USA"),
            AirportResult(iata: "LGA", name: "LaGuardia Airport", city: "New York", country: "USA"),
            AirportResult(iata: "YYZ", name: "Toronto Pearson Airport", city: "Toronto", country: "Canada")
        ]

        return all.filter {
            $0.city?.lowercased().contains(q) == true ||
            $0.name.lowercased().contains(q) ||
            $0.iata.lowercased().contains(q)
        }
    }

    private func score(_ airport: AirportResult, _ q: String) -> Int {
        let city = airport.city?.lowercased() ?? ""
        let name = airport.name.lowercased()
        let iata = airport.iata.lowercased()

        var score = 0

        // 완전 match
        if city == q { score += 100 }
        if iata == q { score += 100 }

        // prefix match (van → vancouver)
        if city.hasPrefix(q) { score += 80 }
        if name.hasPrefix(q) { score += 70 }

        // 포함 match (new → new york)
        if city.contains(q) { score += 50 }
        if name.contains(q) { score += 40 }

        // iata 포함 (yv → yvr)
        if iata.contains(q) { score += 60 }

        return score
    }
 
    // MARK: - Firebase token
    private func fetchFirebaseToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FlightViewModel", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not logged in."])
        }
        let token = try await user.getIDToken(forcingRefresh: false)
        return token
    }
 
    // MARK: - Search flights
    func searchFlights() {
        guard isSearchEnabled, !isSearching else { return }
 
        isSearching  = true
        isLoading    = true
        errorMessage = nil
        flights      = []
        showResults  = true
 
        // 드롭다운 닫기
        showFromSuggestions = false
        showToSuggestions   = false
 
        Task {
            do {
                let token = try await fetchFirebaseToken()
                let start = apiFmt.string(from: departureDate)
                let end   = tripType == .oneWay ? nil : apiFmt.string(from: returnDate)
 
                let trip = try await service.createTrip(
                    from: effectiveFrom.uppercased(),
                    to: effectiveTo.uppercased(),
                    startDate: start,
                    endDate: end,
                    travelers: travelers,
                    cabin: cabinClass.rawValue.lowercased(),
                    idToken: token
                )
 
                let result = try await service.searchFlights(
                    tripId: trip.id,
                    idToken: token
                )
                self.flights = result
 
            } catch {
                self.errorMessage = error.localizedDescription
            }
 
            self.isLoading   = false
            self.isSearching = false
        }
    }
}
