import SwiftUI
import FirebaseAuth

struct DestinationPickerView: View {
    @ObservedObject var vm: TripDraftViewModel
    let userId: String
    @Binding var showPlanning: Bool

    @State private var query: String = ""
    @State private var selectedPlace: DestinationPlace? = nil
    @State private var goToDate = false
    @State private var isAddingMustVisitPlace = false
    @State private var destinationResults: [DestinationSearchResult] = []
    @State private var localDestinationResults: [DestinationPlace] = []
    @State private var placeResults: [PlaceSearchResult] = []
    @State private var mustVisitPlaces: [PlaceSearchResult] = []
    @State private var isSearchingDestinations = false
    @State private var isSearchingPlaces = false
    @State private var searchErrorMessage: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var isSearchFocused: Bool


    private let green = Color(hex: "0B6B3A")
    private let searchGreen = Color(hex: "1F5C47")
    private let tripService = TripService(client: APIClient())

    private let sections: [(String, [DestinationPlace])] = [
        (
            "United States",
            [
                DestinationPlace(city: "New York", iata: "JFK", country: "USA"),
                DestinationPlace(city: "Los Angeles", iata: "LAX", country: "USA"),
                DestinationPlace(city: "San Francisco", iata: "SFO", country: "USA"),
                DestinationPlace(city: "Las Vegas", iata: "LAS", country: "USA"),
                DestinationPlace(city: "Chicago", iata: "ORD", country: "USA"),
                DestinationPlace(city: "Miami", iata: "MIA", country: "USA"),
                DestinationPlace(city: "Seattle", iata: "SEA", country: "USA"),
                DestinationPlace(city: "Boston", iata: "BOS", country: "USA"),
                DestinationPlace(city: "Honolulu", iata: "HNL", country: "USA")
            ]
        ),
        (
            "Canada",
            [
                DestinationPlace(city: "Vancouver", iata: "YVR", country: "Canada"),
                DestinationPlace(city: "Toronto", iata: "YYZ", country: "Canada"),
                DestinationPlace(city: "Montreal", iata: "YUL", country: "Canada"),
                DestinationPlace(city: "Calgary", iata: "YYC", country: "Canada"),
                DestinationPlace(city: "Banff", iata: "YYC", country: "Canada"),
                DestinationPlace(city: "Quebec City", iata: "YQB", country: "Canada")
            ]
        ),
        (
            "Mexico",
            [
                DestinationPlace(city: "Mexico City", iata: "MEX", country: "Mexico"),
                DestinationPlace(city: "Cancun", iata: "CUN", country: "Mexico"),
                DestinationPlace(city: "Tulum", iata: "CUN", country: "Mexico"),
                DestinationPlace(city: "Puerto Vallarta", iata: "PVR", country: "Mexico"),
                DestinationPlace(city: "Los Cabos", iata: "SJD", country: "Mexico")
            ]
        ),
        (
            "France",
            [
                DestinationPlace(city: "Paris", iata: "CDG", country: "France"),
                DestinationPlace(city: "Nice", iata: "NCE", country: "France"),
                DestinationPlace(city: "Lyon", iata: "LYS", country: "France"),
                DestinationPlace(city: "Marseille", iata: "MRS", country: "France")
            ]
        ),
        (
            "United Kingdom",
            [
                DestinationPlace(city: "London", iata: "LHR", country: "United Kingdom"),
                DestinationPlace(city: "Edinburgh", iata: "EDI", country: "United Kingdom"),
                DestinationPlace(city: "Manchester", iata: "MAN", country: "United Kingdom")
            ]
        ),
        (
            "Italy",
            [
                DestinationPlace(city: "Rome", iata: "FCO", country: "Italy"),
                DestinationPlace(city: "Milan", iata: "MXP", country: "Italy"),
                DestinationPlace(city: "Venice", iata: "VCE", country: "Italy"),
                DestinationPlace(city: "Florence", iata: "FLR", country: "Italy")
            ]
        ),
        (
            "Spain",
            [
                DestinationPlace(city: "Barcelona", iata: "BCN", country: "Spain"),
                DestinationPlace(city: "Madrid", iata: "MAD", country: "Spain"),
                DestinationPlace(city: "Seville", iata: "SVQ", country: "Spain"),
                DestinationPlace(city: "Valencia", iata: "VLC", country: "Spain")
            ]
        ),
        (
            "Japan",
            [
                DestinationPlace(city: "Tokyo", iata: "HND", country: "Japan"),
                DestinationPlace(city: "Osaka", iata: "KIX", country: "Japan"),
                DestinationPlace(city: "Kyoto", iata: "KIX", country: "Japan"),
                DestinationPlace(city: "Sapporo", iata: "CTS", country: "Japan"),
                DestinationPlace(city: "Fukuoka", iata: "FUK", country: "Japan")
            ]
        ),
        (
            "South Korea",
            [
                DestinationPlace(city: "Seoul", iata: "ICN", country: "South Korea"),
                DestinationPlace(city: "Busan", iata: "PUS", country: "South Korea"),
                DestinationPlace(city: "Jeju", iata: "CJU", country: "South Korea"),
                DestinationPlace(city: "Incheon", iata: "ICN", country: "South Korea")
            ]
        ),
        (
            "Thailand",
            [
                DestinationPlace(city: "Bangkok", iata: "BKK", country: "Thailand"),
                DestinationPlace(city: "Phuket", iata: "HKT", country: "Thailand"),
                DestinationPlace(city: "Chiang Mai", iata: "CNX", country: "Thailand"),
                DestinationPlace(city: "Krabi", iata: "KBV", country: "Thailand")
            ]
        ),
        (
            "Singapore",
            [
                DestinationPlace(city: "Singapore", iata: "SIN", country: "Singapore")
            ]
        )
    ]

    private var filteredSections: [(String, [DestinationPlace])] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sections }

        let lower = trimmed.lowercased()

        return sections.compactMap { title, places in
            let filtered = places.filter {
                $0.city.lowercased().contains(lower) ||
                $0.country.lowercased().contains(lower) ||
                $0.iata.lowercased().contains(lower)
            }
            return filtered.isEmpty ? nil : (title, filtered)
        }
    }

    private var canSubmit: Bool {
        selectedPlace != nil
    }

    private var isSearchingCityQuery: Bool {
        selectedPlace == nil && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    searchBar

                    if let selectedPlace {
                        selectedDestinationContent(selectedPlace)
                    } else {
                        if isSearchingDestinations {
                            searchLoadingRow("Searching destinations...")
                        } else if !destinationResults.isEmpty || !localDestinationResults.isEmpty {
                            destinationSearchResultsSection
                        } else if isSearchingCityQuery {
                            Text("No destinations found.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(sections, id: \.0) { section in
                                destinationSection(title: section.0, places: section.1)
                            }
                        }
                    }

                    if let searchErrorMessage {
                        Text(searchErrorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red.opacity(0.82))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            bottomButton
        }
        .navigationTitle("Find a Destination")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomBackButton {
                    showPlanning = false
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            syncSelectedPlaceFromDraft()
        }
        .onChange(of: query) { _, newValue in
            handleQueryChange(newValue)
        }
        .navigationDestination(isPresented: $goToDate) {
            DatePageView(vm: vm, showPlanning: $showPlanning)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.gray)

                TextField(searchPlaceholder, text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .submitLabel(selectedPlace == nil ? .search : .done)
                    .onSubmit {
                        handleSearchSubmit()
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.18), lineWidth: 1)
            )

            Button {
                handleSearchSubmit()
            } label: {
                Text(searchButtonTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(searchButtonEnabled ? .white : .white.opacity(0.7))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(searchButtonEnabled ? Color(hex: "1F5C47") : Color(hex: "1F5C47").opacity(0.3))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!searchButtonEnabled)
        }
    }

    private var searchPlaceholder: String {
        if selectedPlace == nil {
            return "Search city or country"
        }

        if isAddingMustVisitPlace, let selectedPlace {
            return "Search places in \(selectedPlace.city)"
        }

        return "Search destination or place"
    }

    private var searchButtonTitle: String {
        if selectedPlace == nil {
            return isSearchingDestinations ? "..." : "Search"
        }

        if isAddingMustVisitPlace {
            return isSearchingPlaces ? "..." : "Search"
        }

        return "Search"
    }

    private var searchButtonEnabled: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if selectedPlace == nil {
            return !trimmed.isEmpty && !isSearchingDestinations
        }

        if isAddingMustVisitPlace {
            return !trimmed.isEmpty && !isSearchingPlaces
        }

        return true
    }


    private func handleQueryChange(_ value: String) {
        searchTask?.cancel()
        searchErrorMessage = nil

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 1 else {
            if selectedPlace == nil {
                destinationResults = []
                localDestinationResults = []
            } else if isAddingMustVisitPlace {
                placeResults = []
            }
            return
        }
        // Additional clearing logic after the above block
        if selectedPlace == nil {
            destinationResults = []
            localDestinationResults = []
        } else if isAddingMustVisitPlace {
            placeResults = []
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            if selectedPlace == nil {
                await searchDestinations(query: trimmed)
            } else if isAddingMustVisitPlace {
                await searchMustVisitPlaces(query: trimmed)
            }
        }
    }

    private func handleSearchSubmit() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            hideKeyboard()
            return
        }

        if selectedPlace == nil {
            Task {
                await searchDestinations(query: trimmed)
            }
            return
        }

        guard isAddingMustVisitPlace else {
            hideKeyboard()
            return
        }

        Task {
            await searchMustVisitPlaces(query: trimmed)
        }
    }


    private func isCityDestination(types: [String]?) -> Bool {
        let types = types ?? []
        let cityTypes = [
            "locality",
            "administrative_area_level_1",
            "administrative_area_level_2",
            "country"
        ]

        return types.contains { cityTypes.contains($0) }
    }

    private func isSpecificPlace(types: [String]?) -> Bool {
        let types = types ?? []
        guard !types.isEmpty else { return true }
        return !isCityDestination(types: types)
    }

    private func isRelevantPlaceResult(_ place: PlaceSearchResult, query: String, selectedCity: String) -> Bool {
        guard isSpecificPlace(types: place.types) else { return false }

        let normalizedName = place.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedAddress = (place.address ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCity = selectedCity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedName.isEmpty else { return false }

        // Backend already searched with query + city + country.
        // Do not require the returned name/address to contain the user's exact query,
        // because searches like "time square" can correctly return "Times Square".
        let isOnlyCityResult = normalizedName == normalizedCity || normalizedAddress == normalizedCity
        return !isOnlyCityResult
    }

    private func localDestinationResults(for query: String) -> [DestinationPlace] {
        let lower = query.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return [] }

        return sections
            .flatMap { $0.1 }
            .filter { place in
                place.city.lowercased().contains(lower) ||
                place.country.lowercased().contains(lower) ||
                place.iata.lowercased().contains(lower)
            }
    }

    @MainActor
    private func searchDestinations(query: String) async {
        guard let idToken = try? await Auth.auth().currentUser?.getIDToken() else {
            searchErrorMessage = "Please sign in again to search destinations."
            return
        }

        isSearchingDestinations = true
        searchErrorMessage = nil
        defer { isSearchingDestinations = false }

        do {
            let localResults = localDestinationResults(for: query)

            let results = try await tripService.searchDestinations(
                query: query,
                idToken: idToken
            )
            let cityOnlyResults = results.filter { isCityDestination(types: $0.types) }

            let filteredLocalResults = localResults.filter { local in
                !cityOnlyResults.contains { server in
                    server.city == local.city && server.country == local.country
                }
            }

            print("DESTINATION RESULTS:", results.count, "CITY ONLY:", cityOnlyResults.count, "LOCAL:", filteredLocalResults.count)
            destinationResults = cityOnlyResults
            localDestinationResults = filteredLocalResults
        } catch {
            print("❌ destination search failed:", error)
            let localResults = localDestinationResults(for: query)
            destinationResults = []
            localDestinationResults = localResults
            searchErrorMessage = localResults.isEmpty ? "Could not search destinations. Please try again." : nil
        }
    }


    @MainActor
    private func searchMustVisitPlaces(query: String) async {
        guard let selectedPlace else { return }
        guard let idToken = try? await Auth.auth().currentUser?.getIDToken() else {
            searchErrorMessage = "Please sign in again to search places."
            return
        }

        isSearchingPlaces = true
        searchErrorMessage = nil
        defer { isSearchingPlaces = false }

        do {
            let results = try await tripService.searchPlaces(
                query: query,
                city: selectedPlace.city,
                country: selectedPlace.country,
                idToken: idToken
            )
            let placeOnlyResults = results.filter {
                isRelevantPlaceResult($0, query: query, selectedCity: selectedPlace.city)
            }
            print("PLACE RESULTS:", results.count, "PLACE ONLY:", placeOnlyResults.count)
            placeResults = placeOnlyResults
        } catch {
            print("❌ place search failed:", error)
            placeResults = []
            searchErrorMessage = "Could not search places. Please try again."
        }
    }

    private func selectDestination(_ result: DestinationSearchResult) {
        let place = DestinationPlace(
            city: result.city,
            iata: result.iata ?? "",
            country: result.country
        )

        selectedPlace = place
        query = ""
        destinationResults = []
        localDestinationResults = []
        placeResults = []
        mustVisitPlaces.removeAll()
        vm.setMustVisitPlaces([])
        isAddingMustVisitPlace = false
        searchTask?.cancel()
        searchErrorMessage = nil

        vm.setDestination(
            city: place.city,
            iata: place.iata,
            country: place.country
        )
    }

    private func selectDestinationPlace(_ place: DestinationPlace) {
        selectedPlace = place
        query = ""
        destinationResults = []
        localDestinationResults = []
        placeResults = []
        mustVisitPlaces.removeAll()
        vm.setMustVisitPlaces([])
        isAddingMustVisitPlace = false
        searchTask?.cancel()
        searchErrorMessage = nil

        vm.setDestination(
            city: place.city,
            iata: place.iata,
            country: place.country
        )
    }

    private func addMustVisitPlace(_ place: PlaceSearchResult) {
        guard !mustVisitPlaces.contains(where: { $0.id == place.id }) else { return }
        mustVisitPlaces.append(place)

        vm.setMustVisitPlaces(
            mustVisitPlaces.map {
                MustVisitPlaceDraft(
                    id: $0.id,
                    name: $0.name,
                    address: $0.address,
                    lat: $0.lat,
                    lng: $0.lng,
                    rating: $0.rating,
                    type: $0.types?.first
                )
            }
        )

        query = ""
        placeResults = []
        isAddingMustVisitPlace = false
        searchTask?.cancel()
        hideKeyboard()
    }

    private func searchLoadingRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }


    private var destinationSearchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(destinationResults) { result in
                    destinationResultButton(
                        city: result.city,
                        country: result.country,
                        action: { selectDestination(result) }
                    )
                }

                ForEach(localDestinationResults) { place in
                    destinationResultButton(
                        city: place.city,
                        country: place.country,
                        action: { selectDestinationPlace(place) }
                    )
                }
            }
        }
    }

    private func destinationResultButton(city: String, country: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(city)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(country)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(searchGreen)
            }
            .padding(13)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func selectedDestinationContent(_ place: DestinationPlace) -> some View {
        VStack(alignment: .leading, spacing: 18) {

            VStack(alignment: .leading, spacing: 14) {
                Text("Selected Destination")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("City")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(place.city)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(Color(.systemBackground))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.22), lineWidth: 1)
                            )

                        Spacer()

                        Button {
                            selectedPlace = nil
                            query = ""
                            destinationResults = []
                            localDestinationResults = []
                            placeResults = []
                            searchErrorMessage = nil
                            isAddingMustVisitPlace = false
                            mustVisitPlaces.removeAll()
                            searchTask?.cancel()
                        } label: {
                            Text("Change")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(green.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Must-Visit Places")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(isAddingMustVisitPlace ? "Use the search bar above to add places in \(place.city)." : "Any must-visit spots? \n(e.g. Eiffel Tower in Paris)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.gray.opacity(0.75))
                    }

                    Spacer()

                    Button {
                        isAddingMustVisitPlace.toggle()
                        searchTask?.cancel()
                        query = ""
                        placeResults = []
                        searchErrorMessage = nil
                        if isAddingMustVisitPlace {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isSearchFocused = true
                            }
                        } else {
                            hideKeyboard()
                        }
                    } label: {
                        Text(isAddingMustVisitPlace ? "Cancel" : "Add Place")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isAddingMustVisitPlace ? Color(hex: "1F5C47") : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isAddingMustVisitPlace ? Color(hex: "1F5C47").opacity(0.08) : Color(hex: "1F5C47"))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(hex: "1F5C47").opacity(0.18), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if isSearchingPlaces {
                    searchLoadingRow("Searching places...")
                }

                if !placeResults.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(placeResults, id: \.id) { place in
                            Button {
                                addMustVisitPlace(place)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(searchGreen)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(place.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        let addressText = place.address?.isEmpty == false ? place.address! : "Address unavailable"
                                        if addressText != place.name {
                                            Text(addressText)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.gray.opacity(0.14), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !mustVisitPlaces.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(mustVisitPlaces, id: \.id) { place in
                            HStack(spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(searchGreen)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(place.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)

                                    if let address = place.address,
                                       !address.isEmpty,
                                       address != place.name {
                                        Text(address)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Button {
                                    mustVisitPlaces.removeAll { $0.id == place.id }
                                    
                                    vm.setMustVisitPlaces(
                                        mustVisitPlaces.map {
                                            MustVisitPlaceDraft(
                                                id: $0.id,
                                                name: $0.name,
                                                address: $0.address,
                                                lat: $0.lat,
                                                lng: $0.lng,
                                                rating: $0.rating,
                                                type: $0.types?.first
                                            )
                                        }
                                    )
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }


    private func destinationSection(title: String, places: [DestinationPlace]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(places) { place in
                    destinationChip(place)
                }
            }
        }
    }

    private func destinationChip(_ place: DestinationPlace) -> some View {
        let isSelected = selectedPlace == place

        return Button {
            selectedPlace = place
            query = ""
            destinationResults = []
            localDestinationResults = []
            placeResults = []
            mustVisitPlaces.removeAll()
            isAddingMustVisitPlace = false
            searchTask?.cancel()
            searchErrorMessage = nil

            vm.setDestination(
                city: place.city,
                iata: place.iata,
                country: place.country
            )
            vm.setMustVisitPlaces([])
        } label: {
            Text(place.city)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? green : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? green : Color.gray.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var bottomButton: some View {
        VStack {
            PrimaryButton(
                title: "NEXT",
                isEnabled: canSubmit
            ) {
                vm.setMustVisitPlaces(
                    mustVisitPlaces.map {
                        MustVisitPlaceDraft(
                            id: $0.id,
                            name: $0.name,
                            address: $0.address,
                            lat: $0.lat,
                            lng: $0.lng,
                            rating: $0.rating,
                            type: $0.types?.first
                        )
                    }
                )

                goToDate = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(Color(.systemBackground))
    }

    private func syncSelectedPlaceFromDraft() {
        guard !vm.draft.destinationCity.isEmpty else { return }

        let savedPlace = DestinationPlace(
            city: vm.draft.destinationCity,
            iata: vm.draft.destinationIATA,
            country: vm.draft.destinationCountry
        )

        for (_, places) in sections {
            if let match = places.first(where: {
                $0.city == vm.draft.destinationCity &&
                $0.iata == vm.draft.destinationIATA &&
                $0.country == vm.draft.destinationCountry
            }) {
                selectedPlace = match
                restoreMustVisitPlacesFromDraft()
                return
            }
        }

        selectedPlace = savedPlace
        restoreMustVisitPlacesFromDraft()
    }

    private func restoreMustVisitPlacesFromDraft() {
        mustVisitPlaces = vm.mustVisitPlaces.map {
            PlaceSearchResult(
                id: $0.id,
                name: $0.name,
                address: $0.address,
                rating: $0.rating,
                price_level: nil,
                types: $0.type == nil ? nil : [$0.type!],
                lat: $0.lat,
                lng: $0.lng,
                photo_url: nil
            )
        }
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}

struct DestinationPlace: Identifiable, Equatable {
    var id: String { "\(city)-\(iata)-\(country)" }

    let city: String
    let iata: String
    let country: String
}

#Preview {
    let vm = TripDraftViewModel(userId: "preview-user")
    vm.setDestination(city: "Seoul", iata: "ICN", country: "South Korea")

    return NavigationStack {
        DestinationPickerView(
            vm: vm,
            userId: "preview-user",
            showPlanning: .constant(true)
        )
    }
}
