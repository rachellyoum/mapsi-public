//
//  TripDetailViewModel.swift
//  TravelPlanner
//
//  Created by Kylie Kim on 2026-04-22.
//

import Foundation
import FirebaseAuth

@MainActor
final class TripDetailViewModel: ObservableObject {

    @Published var itinerary: ItineraryPayload?
    @Published var isLoading = false

    private let tripService = TripService(client: APIClient())
    
    func fetchTripDirect(tripId: String, token: String) async throws -> CreateTripResponse {
        return try await APIClient().get(
            "trips/\(tripId)",
            headers: ["Authorization": "Bearer \(token)"]
        )
    }
    func loadTrip(tripId: String) async {
        guard let user = Auth.auth().currentUser else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await user.getIDToken()

            let trip = try await fetchTripDirect(
                tripId: tripId,
                token: token
            )

            itinerary = trip.itinerary_json

            print("✅ NEW DATA LOADED")

            if let days = trip.itinerary_json?.days {
                for day in days {
                    for item in day.items {
                        print("📍 \(item.place_name) order=\(item.order ?? -1)")
                    }
                }
            }

        } catch {
            print("❌ loadTrip failed:", error)
        }
    }

    func swap(tripId: String, day: Int, a: Int, b: Int) async {
        guard let user = Auth.auth().currentUser else { return }

        do {
            let token = try await user.getIDToken()
            try await tripService.swapStops(
                tripId: tripId,
                day: day,
                a: a,
                b: b,
                idToken: token
            )

            await loadTrip(tripId: tripId)
        } catch {
            print("❌ swap failed:", error)
        }
    }

    func delete(tripId: String, day: Int, order: Int) async {
        guard let user = Auth.auth().currentUser else { return }

        do {
            let token = try await user.getIDToken()
            try await tripService.deleteStop(
                tripId: tripId,
                day: day,
                order: order,
                idToken: token
            )

            await loadTrip(tripId: tripId)
        } catch {
            print("❌ delete failed:", error)
        }
    }
}
