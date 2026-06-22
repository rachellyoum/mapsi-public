//
//  FriendService.swift
//  TravelPlanner
//
//  Created by Kylie Kim on 2026-03-21.
//


import Foundation
 
// MARK: - Models
 
struct FriendUser: Identifiable, Codable {
    let id: String
    let name: String?                   // ✅ null 허용 (서버가 null 보낼 수 있음)
    let email: String
    let profileImageURL: String?
    var avatarColorIndex: Int?  
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case profileImageURL = "profile_image_url"
    }
 
    /// name이 없으면 email을 대신 표시
    var displayName: String {
        let n = name ?? ""
        return n.isEmpty ? email : n
    }
}
 
struct FriendRequest: Identifiable, Codable {
    let id: String
 
    let senderId: String?
    let receiverId: String?
 
    let senderName: String?
    let receiverName: String?
 
    let senderEmail: String?
    let receiverEmail: String?
 
    let status: String?                 // ✅ 서버가 "pending" 등 포함
    let createdAt: String?              // ✅ 서버 응답 필드
 
    enum CodingKeys: String, CodingKey {
        case id
        case senderId     = "sender_id"
        case receiverId   = "receiver_id"
        case senderName   = "sender_name"
        case receiverName = "receiver_name"
        case senderEmail  = "sender_email"
        case receiverEmail = "receiver_email"
        case status
        case createdAt    = "created_at"
    }
}
 
struct FriendCountResponse: Decodable {
    let count: Int
}
 
struct FriendSuccessResponse: Decodable {
    let success: Bool?
    let message: String?
    let status: String?
}
 
// MARK: - FriendService
 
struct FriendService {
    let client: APIClient
 
    // GET /friends
    func fetchFriends(idToken: String) async throws -> [FriendUser] {
        try await client.get(
            "friends",
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }
 
    // GET /friends/count
    func fetchFriendCount(idToken: String) async throws -> FriendCountResponse {
        try await client.get(
            "friends/count",
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }
 
    // GET /friends/requests/incoming
    func fetchIncomingRequests(idToken: String) async throws -> [FriendRequest] {
        try await client.get(
            "friends/requests/incoming",
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }
 
    // GET /friends/requests/outgoing
    func fetchOutgoingRequests(idToken: String) async throws -> [FriendRequest] {
        try await client.get(
            "friends/requests/outgoing",
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }
 
    // POST /friends/request  body: { "email": "..." }
    // ✅ FriendSuccessResponse 반환 → ViewModel에서 message 확인 가능
    func sendRequest(email: String, idToken: String) async throws -> FriendSuccessResponse {
        struct Body: Encodable { let email: String }
        return try await client.post(
            "friends/request",
            body: Body(email: email),
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }
 
    // POST /friends/request/{request_id}/accept
    func acceptRequest(requestId: String, idToken: String) async throws {
        let _: FriendSuccessResponse = try await client.post(
            "friends/request/\(requestId)/accept",
            body: EmptyBody(),
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }
 
    // POST /friends/request/{request_id}/decline
    func declineRequest(requestId: String, idToken: String) async throws {
        let _: FriendSuccessResponse = try await client.post(
            "friends/request/\(requestId)/decline",
            body: EmptyBody(),
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }
 
    // DELETE /friends/{friend_user_id}
    func removeFriend(userId: String, idToken: String) async throws {
        try await client.delete(
            "friends/\(userId)",
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }
 
    // POST /friends/block  body: { "email": "..." }
    func block(user: FriendUser, idToken: String) async throws {
        struct Body: Encodable { let email: String }

        let _: FriendSuccessResponse = try await client.post(
            "friends/block",
            body: Body(email: user.email),
            headers: ["Authorization": "Bearer \(idToken)"]
        )
    }
}


