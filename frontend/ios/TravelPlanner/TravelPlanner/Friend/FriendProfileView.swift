//
//  FriendProfileView.swift
//  TravelPlanner
//


import SwiftUI
import FirebaseAuth

// MARK: - Shared Trip Model

struct SharedTrip: Identifiable {
    let id: String
    let city: String
    let country: String
    let dateRange: String
    let itinerary: ItineraryPayload   // 🔥 추가
}
// MARK: - ViewModel

@MainActor
final class FriendProfileViewModel: ObservableObject {
    @Published var sharedTrips: [SharedTrip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let tripService = TripService(client: APIClient())

    func loadSharedTrips(with friendId: String) async {
        guard let currentUser = Auth.auth().currentUser else { return }

        isLoading = true
        defer { isLoading = false }
        
        

        do {
            let token = try await currentUser.getIDToken()

            let allTrips = try await tripService.fetchMyTrips(idToken: token)
            print("🔍 total trips fetched:", allTrips.count)

            var shared: [SharedTrip] = []
            var seenIds = Set<String>()

            for trip in allTrips {
                guard !seenIds.contains(trip.id) else { continue }

                guard let members = try? await tripService.fetchTripMembers(
                    tripId: trip.id,
                    idToken: token
                ) else {
                    print("   ⚠️ couldn't fetch members for trip:", trip.id)
                    continue
                }

                let memberIds = Set(members.map { $0.user_id })
                print("   trip '\(trip.destination_city)' members:", memberIds)

               
                if memberIds.contains(friendId) {
                    seenIds.insert(trip.id)
                    guard let itinerary = trip.itinerary_json else {
                        print("❌ itinerary 없음:", trip.id)
                        continue
                    }

                    shared.append(SharedTrip(
                        id: trip.id,
                        city: trip.destination_city,
                        country: trip.destination_country,
                        dateRange: formatDateRange(trip.start_datetime, trip.end_datetime),
                        itinerary: itinerary   // 🔥 추가
                    ))
                    print("🔥 friendId:", friendId)
                    print("🔥 memberIds:", memberIds)
                    print("   ✅ added shared trip:", trip.destination_city)
                }
            }

            print("✅ total shared trips found:", shared.count)
            sharedTrips = shared

        } catch {
            print("❌ loadSharedTrips failed:", error)
            errorMessage = error.localizedDescription
        }
    }

    private func formatDateRange(_ start: String?, _ end: String?) -> String {
        guard let start else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let display = DateFormatter()
        display.dateStyle = .medium
        let startStr = formatter.date(from: start).map { display.string(from: $0) } ?? String(start.prefix(10))
        let endStr   = end.flatMap { formatter.date(from: $0).map { display.string(from: $0) } } ?? String((end ?? "").prefix(10))
        return "\(startStr) – \(endStr)"
    }
}

// MARK: - View

struct FriendProfileView: View {
    let friend: FriendUser
    @ObservedObject var friendVM: FriendViewModel
    @StateObject private var vm = FriendProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showManage = false

    private let green = Color(hex: "0B6B3A")
    private let lightGreen = Color(hex: "004428")

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // ── Hero / Avatar ────────────────────────────────────
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [green.opacity(0.85), lightGreen],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 180)

                    VStack(spacing: 10) {
                        Circle()
                            .fill(
                                AvatarPalette.colors[
                                    (friend.avatarColorIndex ?? 0) % AvatarPalette.colors.count
                                ]
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Group {
                                    if let urlStr = friend.profileImageURL,
                                       let url = URL(string: urlStr) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 34))
                                                .foregroundColor(.white)
                                        }
                                    } else {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 34))
                                            .foregroundColor(.white)
                                    }
                                }
                            )
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 2))
                            .offset(y: 36)
                    }
                }

                // ── Name / Email ─────────────────────────────────────
                VStack(spacing: 4) {
                    Text(friend.displayName)
                        .font(.system(size: 20, weight: .bold))

                    Text(friend.email)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 48)
                .padding(.bottom, 20)

                // ── Action Buttons ───────────────────────────────────
                HStack(spacing: 12) {
                    Button {
                        showManage = true
                    } label: {
                        Label("Manage", systemImage: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(green)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(green.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 28)

                Divider()
                    .padding(.horizontal, 20)

                // ── Shared Trips ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Shared Trips")
                            .font(.system(size: 17, weight: .bold))
                        Spacer()
                        if !vm.sharedTrips.isEmpty {
                            Text("\(vm.sharedTrips.count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(green.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    if vm.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.top, 20)

                    } else if vm.sharedTrips.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "airplane.circle")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("No shared trips yet")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)

                    } else {
                        VStack(spacing: 12) {
                            ForEach(vm.sharedTrips) { trip in
                                NavigationLink {
                                    TripResultView(
                                        response: GenerateTripResponse(
                                            trip_id: trip.id,
                                            itinerary: trip.itinerary,
                                            cached: true
                                        ),
                                        selectedPlace: DestinationPlace(
                                            city: trip.city,
                                            iata: "---",
                                            country: trip.country
                                        ),
                                        mode: .saved
                                    )
                                } label: {
                                    SharedTripCard(
                                        city: trip.city,
                                        country: trip.country,
                                        dateRange: trip.dateRange,
                                        accentColor: green
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(friend.displayName)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .sheet(isPresented: $showManage) {
            ManageSheet(friend: friend, vm: friendVM, isPresented: $showManage)
        }
        .task {
            await vm.loadSharedTrips(with: friend.id)
        }
    }
}

// MARK: - Shared Trip Card

struct SharedTripCard: View {
    let city: String
    let country: String
    let dateRange: String
    let accentColor: Color
    
    @State private var imageURL: String?
    private let mediaService = MediaService()

    var body: some View {
        HStack(spacing: 14) {

            // ✅ 왼쪽 정사각형 도시 이미지
            Group {
                if let urlStr = imageURL,
                   let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                } else {
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 70, height: 70)   // 🔥 핵심: 정사각형
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // ✅ 텍스트 영역
            VStack(alignment: .leading, spacing: 6) {
                Text(city)
                    .font(.system(size: 16, weight: .semibold))

                Text(country)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(accentColor)

                    Text(dateRange)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )

        // ✅ MediaService 그대로 사용 (로직 유지)
        .task {
            imageURL = try? await mediaService.fetchCityPhotoURL(city: city)
        }
    }
}
// MARK: - Shared Trip Detail View

/// SharedTrip을 탭했을 때 보여주는 상세 뷰.
/// TripResultView를 사용하려면 이 뷰 대신 TripResultView로 연결하면 됩니다.
struct SharedTripDetailView: View {
    let trip: SharedTrip
    private let green = Color(hex: "0B6B3A")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero image
                let imageName = DestinationImageProvider.imageName(for: trip.city, country: trip.country)
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.city)
                        .font(.system(size: 28, weight: .bold))
                    Text(trip.country)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)

                    if !trip.dateRange.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .foregroundColor(green)
                            Text(trip.dateRange)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle(trip.city)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FriendProfileView(
            friend: FriendUser(id: "1", name: "Kylie", email: "kylie@example.com", profileImageURL: nil),
            friendVM: FriendViewModel()
        )
    }
}
