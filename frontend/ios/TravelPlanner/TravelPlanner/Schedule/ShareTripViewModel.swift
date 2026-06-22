//
//  ShareTripViewModel.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-18.
//


import Foundation
import FirebaseAuth

@MainActor
final class ShareTripViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var users: [UserSearchResponse] = []
    @Published var members: [TripMemberResponse] = []
    @Published var isLoading = false
    @Published var isSharing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var allFriendsForSharing: [UserSearchResponse] = []

    private let tripService = TripService(client: APIClient())

    func searchUsers(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= 2 else {
            users = []
            errorMessage = nil
            return
        }

        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "User is not logged in."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await currentUser.getIDToken()

            if allFriendsForSharing.isEmpty {
                allFriendsForSharing = try await fetchFriendsForSharing(idToken: token)
            }

            let lowercasedQuery = trimmed.lowercased()
            users = allFriendsForSharing.filter { friend in
                let name = friend.name?.lowercased() ?? ""
                let email = friend.email?.lowercased() ?? ""
                return name.contains(lowercasedQuery) || email.contains(lowercasedQuery)
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("searchUsers failed:", error)
        }
    }

    func loadMembers(tripId: String) async {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "User is not logged in."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await currentUser.getIDToken()
            async let membersTask = tripService.fetchTripMembers(tripId: tripId, idToken: token)
            async let friendsTask = fetchFriendsForSharing(idToken: token)

            members = try await membersTask
            allFriendsForSharing = try await friendsTask
        } catch {
            errorMessage = error.localizedDescription
            print("loadMembers failed:", error)
        }
    }

    func shareTrip(tripId: String, targetUserId: String, role: String) async {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "User is not logged in."
            return
        }

        guard allFriendsForSharing.contains(where: { $0.id == targetUserId }) else {
            errorMessage = "You can only share trips with friends."
            return
        }

        isSharing = true
        successMessage = nil
        defer { isSharing = false }

        do {
            let token = try await currentUser.getIDToken()
            _ = try await tripService.shareTrip(
                tripId: tripId,
                targetUserId: targetUserId,
                role: role,
                idToken: token
            )
            successMessage = "Trip shared successfully."
            await loadMembers(tripId: tripId)
        } catch {
            errorMessage = error.localizedDescription
            print("shareTrip failed:", error)
        }
    }
    private func fetchFriendsForSharing(idToken: String) async throws -> [UserSearchResponse] {
        guard let url = URL(string: "https://mapsi-backend-637742275322.us-west1.run.app/friends") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let friends = try decoder.decode([ShareFriendResponse].self, from: data)

        return friends.compactMap { friend in
            guard let id = friend.resolvedId, !id.isEmpty else { return nil }
            return UserSearchResponse(
                id: id,
                name: friend.resolvedName,
                email: friend.resolvedEmail
            )
        }
    }

    private struct ShareFriendResponse: Decodable {
        let id: String?
        let user_id: String?
        let friend_id: String?
        let friend_user_id: String?
        let name: String?
        let email: String?
        let friend_name: String?
        let friend_email: String?
        let display_name: String?

        var resolvedId: String? {
            friend_user_id ?? friend_id ?? user_id ?? id
        }

        var resolvedName: String? {
            friend_name ?? name ?? display_name
        }

        var resolvedEmail: String? {
            friend_email ?? email
        }
    }
}
