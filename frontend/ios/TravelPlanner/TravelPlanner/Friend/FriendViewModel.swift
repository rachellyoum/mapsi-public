import Foundation
import FirebaseAuth
import FirebaseFirestore   
 
@MainActor
final class FriendViewModel: ObservableObject {
 
    // MARK: - Published
 
    @Published var friends: [FriendUser]              = []
    @Published var incomingRequests: [FriendRequest]  = []
    @Published var outgoingRequests: [FriendRequest]  = []
    @Published var friendCount: Int                   = 0
 
    @Published var isLoading                          = false
    @Published var isSendingRequest                   = false
    @Published var showAddFriend                      = false
    @Published var showIncomingRequests               = false
 
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var searchResults: [UserSearchResponse] = []
    @Published var isSearchingUsers                   = false
 
    private var searchTask: Task<Void, Never>?
 
    // MARK: - Private
 
    private let friendService = FriendService(client: APIClient())
 
    // MARK: - Load All
 
    func loadAll() async {
        guard let currentUser = Auth.auth().currentUser else { return }
 
        isLoading = true
        defer { isLoading = false }
 
        do {
            let token = try await currentUser.getIDToken()
 
            async let friendsResult  = friendService.fetchFriends(idToken: token)
            async let countResult    = friendService.fetchFriendCount(idToken: token)
            async let incomingResult = friendService.fetchIncomingRequests(idToken: token)
            async let outgoingResult = friendService.fetchOutgoingRequests(idToken: token)
 
            var loadedFriends = try await friendsResult

            for i in 0..<loadedFriends.count {
                let uid = loadedFriends[i].id
                let color = await fetchAvatarColor(for: uid)
                loadedFriends[i].avatarColorIndex = color
            }

            friends = loadedFriends
            friendCount      = try await countResult.count
            incomingRequests = try await incomingResult
            outgoingRequests = try await outgoingResult
 
        } catch {
            errorMessage = "Couldn't load friends"
            print("loadAll failed:", error)
        }
    }
 
 
    // MARK: - Send Request

    func sendRequest(email: String) async {
        guard let currentUser = Auth.auth().currentUser else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter an email."
            return
        }

        isSendingRequest = true
        errorMessage = nil
        successMessage = nil
        defer { isSendingRequest = false }

        do {
            let token = try await currentUser.getIDToken()
            let response = try await friendService.sendRequest(email: trimmedEmail, idToken: token)

            if response.success == true || response.status == "pending" {
                successMessage = response.message ?? "Friend request sent!"
                await loadAll()
                return
            }

            errorMessage = response.message ?? "Request failed."
        } catch {
            let message = String(describing: error)

            if message.localizedCaseInsensitiveContains("pending friend request already exists") {
                successMessage = "Friend request is already pending."
                await loadAll()
            } else {
                errorMessage = "Request failed."
                print("sendRequest failed:", error)
            }
        }
    }
    // MARK: - Search Users
 
    func searchUsers(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
 
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
 
        guard let user = Auth.auth().currentUser else { return }
 
        isSearchingUsers = true
        defer { isSearchingUsers = false }
 
        do {
            let token = try await user.getIDToken()
            let tripService = TripService(client: APIClient())
            searchResults = try await tripService.searchUsers(query: trimmed, idToken: token)
        } catch {
            print("❌ searchUsers failed:", error)
            searchResults = []
        }
    }
 
    func searchUsersDebounced(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            guard !Task.isCancelled else { return }
            await searchUsers(query: query)
        }
    }
 
    // MARK: - Friend Status Helpers
 
    func isAlreadyFriend(_ email: String?) -> Bool {
        guard let email, !email.isEmpty else { return false }
        return friends.contains { $0.email == email }
    }
 
    func isPending(_ email: String?) -> Bool {
        guard let email else { return false }

        return outgoingRequests.contains {
            $0.receiverEmail == email && $0.status == "pending"
        }
    }
 
    // MARK: - Accept / Decline
    func acceptRequest(_ request: FriendRequest) async {
        guard let currentUser = Auth.auth().currentUser else { return }

        do {
            let token = try await currentUser.getIDToken()
            try await friendService.acceptRequest(requestId: request.id, idToken: token)

            await loadAll() // 🔥 통일

        } catch {
            errorMessage = "Failed to accept request."
        }
    }
 
    func declineRequest(_ request: FriendRequest) async {
        guard let currentUser = Auth.auth().currentUser else { return }
        do {
            let token = try await currentUser.getIDToken()
            try await friendService.declineRequest(requestId: request.id, idToken: token)
            incomingRequests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = "Failed to decline request."
            print("declineRequest failed:", error)
        }
    }
 
    // MARK: - Remove Friend
 
    func removeFriend(_ user: FriendUser) async {
        guard let currentUser = Auth.auth().currentUser else { return }

        do {
            let token = try await currentUser.getIDToken()

            // ✅ 1. 삭제
            try await friendService.removeFriend(userId: user.id, idToken: token)

            // ✅ 2. 백엔드 말대로 전부 다시 fetch (핵심)
            await loadAll()

            successMessage = "Friend removed"

        } catch {
            errorMessage = "Failed to remove friend."
            print("removeFriend failed:", error)
        }
    }
    // MARK: - Block
 
    func block(_ user: FriendUser) async {
        guard let currentUser = Auth.auth().currentUser else { return }

        do {
            let token = try await currentUser.getIDToken()

            try await friendService.block(user: user, idToken: token)

            // ✅ 이것도 서버 기준으로 sync
            await loadAll()

            successMessage = "User blocked"

        } catch {
            errorMessage = "Failed to block."
        }
    }
    func isBlocked(_ email: String?) -> Bool {
        guard let email else { return false }
        // 👉 서버에서 blocked 리스트 받아오는게 베스트
        return false
    }
    func fetchAvatarColor(for uid: String) async -> Int? {
        let doc = try? await Firestore.firestore()
            .collection("users")
            .document(uid)
            .getDocument()

        return doc?.data()?["avatarColorIndex"] as? Int
    }
}
