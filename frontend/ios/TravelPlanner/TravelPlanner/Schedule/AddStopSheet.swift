//
//  AddStopSheet.swift
//  TravelPlanner
//

import SwiftUI
import FirebaseAuth

// MARK: - ViewModel

@MainActor
final class AddStopViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [PlaceSearchResult] = []
    @Published var isSearching = false
    @Published var isAdding = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private var searchTask: Task<Void, Never>?
    private let tripService = TripService(client: APIClient())
    var destinationCity: String = ""
    var tripId: String = ""
    private func isCityDestination(types: [String]?) -> Bool {
        let types = types ?? []
        let cityTypes = [
            "locality",
            "administrative_area_level_1",
            "administrative_area_level_2",
            "country",
            "political"
        ]

        return types.contains { cityTypes.contains($0) }
    }

    private func isSpecificPlace(types: [String]?) -> Bool {
        guard let types, !types.isEmpty else { return true }
        return !isCityDestination(types: types)
    }

    struct PlaceSearchResult: Identifiable {
        let id: String        // place_id
        let name: String
        let address: String?
        let lat: Double?
        let lng: Double?
        let type: String?
        let rating: Double?
    }

    func searchDebounced(_ text: String) {
        searchTask?.cancel()
        guard text.count >= 2 else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await search(text)
        }
    }

    private func search(_ query: String) async {
        guard let user = Auth.auth().currentUser else { return }
        isSearching = true
        defer { isSearching = false }

        do {
            let token = try await user.getIDToken()

            let raw: [TravelPlanner.PlaceSearchResult]

            if !tripId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Generated-trip add stop search should use the trip-scoped lookup endpoint.
                // Backend already knows the trip destination, so this returns real places instead of city/country results.
                raw = try await tripService.lookupTripPlaces(
                    tripId: tripId,
                    query: query,
                    idToken: token
                )
            } else {
                // Fallback: same city-scoped query style as must-visit search.
                // This must use searchPlaces, because searchDestinations returns DestinationSearchResult.
                raw = try await tripService.searchPlaces(
                    query: query,
                    city: destinationCity,
                    country: "",
                    idToken: token
                )
            }

            let placeOnlyResults = raw.filter { isSpecificPlace(types: $0.types) }

            results = placeOnlyResults.map {
                PlaceSearchResult(
                    id: $0.id,
                    name: $0.name,
                    address: $0.address,
                    lat: $0.lat,
                    lng: $0.lng,
                    type: $0.types?.first,
                    rating: $0.rating
                )
            }
        } catch {
            print("❌ place search failed:", error)
            results = []
        }
    }

    func addStop(tripId: String, day: Int, place: PlaceSearchResult, position: Int, scheduleVM: MyScheduleViewModel) async {
        guard let user = Auth.auth().currentUser else { return }
        isAdding = true
        defer { isAdding = false }

        do {
            let token = try await user.getIDToken()
            try await tripService.addStop(
                tripId: tripId,
                day: day,
                body: AddStopRequest(
                    insert_position: position,
                    stop: AddStopBody(
                        place_id: place.id,
                        place_name: place.name,
                        activity: "Visit \(place.name)",
                        address: place.address,
                        lat: place.lat,
                        lng: place.lng,
                        type: place.type,
                        rating: place.rating
                    )
                ),
                idToken: token
            )
            successMessage = "Stop added!"
            scheduleVM.loadTrips()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ addStop failed:", error)
        }
    }
}

// MARK: - View

struct AddStopSheet: View {
    let tripId: String
    let dayNumber: Int
    let destinationCity: String
    let scheduleVM: MyScheduleViewModel
    @Binding var isPresented: Bool
    let onAdded: (() -> Void)?

    @StateObject private var vm = AddStopViewModel()
    @State private var insertPosition: Int = 1

    private let green = Color(hex: "0B6B3A")

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search for a place...", text: $vm.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: vm.query) { _, newVal in
                            vm.searchDebounced(newVal)
                        }

                    if !vm.query.isEmpty {
                        Button {
                            vm.query = ""
                            vm.results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Insert position picker
                HStack {
                    Text("Insert at position")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Stepper("\(insertPosition)", value: $insertPosition, in: 1...20)
                        .labelsHidden()

                    Text("\(insertPosition)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(green)
                        .frame(width: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Divider()
                    .padding(.top, 12)

                // Results
                if vm.isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if vm.results.isEmpty && !vm.query.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("No places found")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(vm.results) { place in
                                Button {
                                    Task {
                                        await vm.addStop(
                                            tripId: tripId,
                                            day: dayNumber,
                                            place: place,
                                            position: insertPosition,
                                            scheduleVM: scheduleVM
                                        )
                                        if vm.successMessage != nil {
                                            onAdded?()
                                            isPresented = false
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(green.opacity(0.10))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundStyle(green)
                                                .font(.system(size: 20))
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(place.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(.primary)
                                            if let address = place.address, !address.isEmpty {
                                                Text(address)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()

                                        if vm.isAdding {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "plus.circle")
                                                .foregroundStyle(green)
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(vm.isAdding)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Add Stop – Day \(dayNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
        .onAppear {
            vm.tripId = tripId
            vm.destinationCity = destinationCity
        }
    }
}
