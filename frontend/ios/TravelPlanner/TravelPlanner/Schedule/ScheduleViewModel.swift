//
//  ScheduleViewModel.swift
//  TravelPlanner
//
//  Created by Kylie Kim on 2026-03-16.
//

import Foundation
import SwiftUI
import FirebaseAuth

struct MyScheduleItem: Identifiable, Codable { //fix
    let id: String
    let city: String
    let country: String
    let startDate: Date
    let endDate: Date
    let itinerary: GenerateTripResponse
    var members: [TripMemberResponse]?

    // ✅ 이거 추가
    var themes: [String]? = nil
}

@MainActor
final class MyScheduleViewModel: ObservableObject {

    @Published var trips: [MyScheduleItem] = []
    @Published var isLoading = false

    private let tripService = TripService(client: APIClient())

    init() {
        loadTrips()
    }

    func loadTrips() {
        Task {
            await fetchTripsFromServer()
        }
    }

    private func fetchTripsFromServer() async { //fix
        guard let currentUser = Auth.auth().currentUser else {
            trips = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await currentUser.getIDToken()
            let serverTrips = try await tripService.fetchMyTrips(idToken: token)

            // 1️⃣ Build items first (no members yet)
            var items: [MyScheduleItem] = serverTrips.compactMap { trip -> MyScheduleItem? in
                guard
                    let start = parseBackendDate(trip.start_datetime),
                    let end = parseBackendDate(trip.end_datetime),
                    let itineraryPayload = trip.itinerary_json
                else {
                    return nil
                }

                return MyScheduleItem(
                    id: trip.id,
                    city: trip.destination_city,
                    country: trip.destination_country,
                    startDate: start,
                    endDate: end,
                    itinerary: GenerateTripResponse(
                        trip_id: trip.id,
                        itinerary: itineraryPayload,
                        cached: true
                    ),
                    members: nil
                )
            }

            // Show cards immediately while members load
            trips = items

            // 2️⃣ Fetch members for every trip concurrently
            await withTaskGroup(of: (String, [TripMemberResponse]).self) { group in
                for item in items {
                    group.addTask {
                        do {
                            let members = try await self.tripService.fetchTripMembers(
                                tripId: item.id,
                                idToken: token
                            )
                            return (item.id, members)
                        } catch {
                            print("fetchTripMembers failed for \(item.id):", error.localizedDescription)
                            return (item.id, [])
                        }
                    }
                }

                for await (tripId, members) in group {
                    if let index = items.firstIndex(where: { $0.id == tripId }) {
                        items[index].members = members
                    }
                }
            }

            // 3️⃣ Publish the fully-populated list
            trips = items

        } catch {
            print("fetchTripsFromServer failed:", error.localizedDescription)
            trips = []
        }
    }

    private func parseBackendDate(_ value: String?) -> Date? {
        guard let value else { return nil }

        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFraction.date(from: value) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: value)
    }

    func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    func deleteItinerary(_ trip: MyScheduleItem) {
        Task {
            guard let currentUser = Auth.auth().currentUser else { return }
            do {
                let token = try await currentUser.getIDToken()
                try await tripService.deleteItinerary(tripId: trip.id, idToken: token)
                await fetchTripsFromServer()
            } catch {
                print("deleteItinerary failed:", error.localizedDescription)
            }
        }
    }

    func addStop(
            tripId: String,
            day: Int,
            placeId: String,
            position: Int
        ) {
            Task {
                guard let currentUser = Auth.auth().currentUser else { return }

                do {
                    let token = try await currentUser.getIDToken()

                    try await tripService.addStop(
                        tripId: tripId,
                        day: day,
                        body: AddStopRequest(
                            insert_position: position,
                            stop: AddStopBody(
                                place_id: placeId,
                                place_name: "New Stop",
                                activity: "Visit New Stop",
                                address: nil,
                                lat: nil,
                                lng: nil,
                                type: nil,
                                rating: nil
                            )
                        ),
                        idToken: token
                    )

                    // 👉 추가 후 다시 fetch
                    await fetchTripsFromServer()

                } catch {
                    print("addStop failed:", error.localizedDescription)
                }
            }
        }

    func swapStops(tripId: String, day: Int, a: Int, b: Int) {
        Task {
            guard let currentUser = Auth.auth().currentUser else { return }
            do {
                let token = try await currentUser.getIDToken()
                try await tripService.swapStops(tripId: tripId, day: day, a: a, b: b, idToken: token)
                await fetchTripsFromServer()
            } catch {
                print("swapStops failed:", error.localizedDescription)
            }
        }
    }

    func deleteStop(tripId: String, day: Int, order: Int) {
        Task {
            guard let currentUser = Auth.auth().currentUser else { return }
            do {
                let token = try await currentUser.getIDToken()
                try await tripService.deleteStop(tripId: tripId, day: day, order: order, idToken: token)
                await fetchTripsFromServer()
            } catch {
                print("deleteStop failed:", error.localizedDescription)
            }
        }
    }
}
