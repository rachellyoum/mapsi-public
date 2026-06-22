import SwiftUI
import FirebaseAuth

struct ScheduleView: View {
    @StateObject private var viewModel = MyScheduleViewModel()
    @State private var selectedTripForShare: MyScheduleItem?
    private let deepGreen = Color(hex: "0B6B3A")

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Text("My Schedule")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.trips.isEmpty {
                        emptyStateView
                    } else {
                        List {
                            ForEach(viewModel.trips) { item in
                                ScheduleSwipeRow(
                                    item: item,
                                    format: viewModel.format,
                                    accentColor: deepGreen,
                                    onShare: {
                                        selectedTripForShare = item
                                    },
                                    onDelete: {
                                        withAnimation {
                                            viewModel.deleteItinerary(item)
                                        }
                                    }
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .onAppear {
                viewModel.loadTrips()
            }
            .sheet(item: $selectedTripForShare) { trip in
                ShareTripView(tripId: trip.id)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(deepGreen.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "airplane.departure")
                    .font(.system(size: 40))
                    .foregroundColor(deepGreen)
            }
            VStack(spacing: 8) {
                Text("No upcoming trips")
                    .font(.system(size: 20, weight: .bold))
                Text("Your next trip is just a tap away!")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Custom Swipe Row

private struct ScheduleSwipeRow: View {
    let item: MyScheduleItem
    let format: (Date) -> String
    let accentColor: Color
    let onShare: () -> Void
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var startOffsetX: CGFloat = 0

    private let revealWidth: CGFloat = 150

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 14) {
                swipeActionButton(
                    icon: "trash",
                    title: "Delete",
                    tint: .red,
                    action: onDelete
                )

                swipeActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    tint: accentColor,
                    action: onShare
                )
            }
            .padding(.trailing, 22)

            ZStack {
                ScheduleCardView(
                    item: item,
                    format: format,
                    accentColor: accentColor
                )

                NavigationLink {
                    TripResultView(
                        response: item.itinerary,
                        selectedPlace: DestinationPlace(
                            city: item.city,
                            iata: "---",
                            country: item.country
                        ),
                        mode: .saved
                    )
                } label: {
                    EmptyView()
                }
                .opacity(0.01)
            }
            .contentShape(Rectangle())
            .offset(x: offsetX)
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let proposed = startOffsetX + value.translation.width
                        offsetX = min(0, max(-revealWidth, proposed))
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            if value.translation.width < -45 || offsetX < -revealWidth / 2 {
                                offsetX = -revealWidth
                            } else {
                                offsetX = 0
                            }
                            startOffsetX = offsetX
                        }
                    }
            )
        }
    }

    private func swipeActionButton(
        icon: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                offsetX = 0
                startOffsetX = 0
            }
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.6), tint.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                    )
                    .shadow(color: tint.opacity(0.18), radius: 8, x: 0, y: 4)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Schedule Card

struct ScheduleCardView: View { //fix
    let item: MyScheduleItem
    let format: (Date) -> String
    let accentColor: Color

    @State private var heroPhotoURL: String? = nil
    @State private var isLoadingHeroPhoto = false
    
    
    private let mediaService = MediaService()

    /// Converts TripMemberResponse → AvatarStackView.AvatarMember
    private var avatarMembers: [AvatarStackView.AvatarMember] {
        let currentEmail = Auth.auth().currentUser?.email?.lowercased()
        let currentUID = Auth.auth().currentUser?.uid

        return (item.members ?? [])
            .filter { member in
                let memberEmail = member.email?.lowercased()
                let memberID = member.user_id

                if let currentEmail, memberEmail == currentEmail { return false }
                if let currentUID, memberID == currentUID { return false }

                return true
            }
            .map { m in
                AvatarStackView.AvatarMember(
                    id: m.user_id,
                    displayName: m.name ?? m.email ?? m.user_id,
                    colorIndex: m.avatarColorIndex   // ✅ 핵심
                )
            }
    }

    private var isShared: Bool { !avatarMembers.isEmpty }

    private var tripDays: Int {
        let days = Calendar.current.dateComponents([.day], from: item.startDate, to: item.endDate).day ?? 0
        return days + 1
    }

    private var heroImageName: String {
        DestinationImageProvider.imageName(for: item.city, country: item.country)
    }

    // MARK: Hero backgrounds

    @ViewBuilder
    private var heroBackground: some View {
        if let heroPhotoURL, let url = URL(string: heroPhotoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:              loadingHeroBackground
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 175, maxHeight: 175, alignment: .top)
                        .clipped()
                case .failure:            fallbackHeroImage
                @unknown default:         fallbackHeroImage
                }
            }
        } else if isLoadingHeroPhoto {
            loadingHeroBackground
        } else {
            fallbackHeroImage
        }
    }

    private var fallbackHeroImage: some View {
        Image(heroImageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, minHeight: 175, maxHeight: 175, alignment: .top)
            .clipped()
    }

    private var loadingHeroBackground: some View {
        ZStack {
            Color(.tertiarySystemFill)
            ProgressView().tint(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 175, maxHeight: 175, alignment: .top)
        .clipped()
    }

    private func loadHeroPhoto() async {
        let city = item.city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty, !isLoadingHeroPhoto else { return }
        isLoadingHeroPhoto = true
        defer { isLoadingHeroPhoto = false }
        do {
            heroPhotoURL = try await mediaService.fetchCityPhotoURL(city: city)
        } catch {
            print("Failed to load schedule hero photo:", error.localizedDescription)
            heroPhotoURL = nil
        }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Hero image + overlay
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomLeading) {
                    heroBackground

                    LinearGradient(
                        colors: [.black.opacity(0.05), .black.opacity(0.18), .black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.city)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        Text(item.country)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .padding(16)
                }

                // Chevron — top right
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(12)

                // Shared avatars — top left  (uses AvatarStyle.swift)
                if isShared {
                    AvatarStackView(members: avatarMembers, avatarSize: 34, showsTooltip: true)
                        .padding(.top, 14)
                        .padding(.leading, 14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 175)
            .clipped()

            // Date / info row
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)

                    Text("\(format(item.startDate)) - \(format(item.endDate))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.78))

                    Spacer()

                    Text("\(tripDays)-day trip")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(accentColor.opacity(0.10))
                        .clipShape(Capsule())
                }

                Divider()

                HStack(spacing: 10) { //fix
                    if !tripThemes.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(tripThemes, id: \.self) { theme in
                                        infoPill(icon: "sparkles", text: theme)
                                    }
                                }
                            }
                        }

                        if isShared {
                            infoPill(icon: "person.2.fill", text: "Shared", tint: AvatarPalette.colors[0])
                        }

                        Spacer()

                        Text(dateStatusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color.white)
        }
        .background(Color.white)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .compositingGroup()
        .shadow(
            color: .black.opacity(0.08),
            radius: 12,
            x: 0,
            y: 6
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .task { await loadHeroPhoto() }
    }

    // MARK: Helpers

    private func infoPill(icon: String, text: String, tint: Color? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(tint ?? Color.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((tint ?? Color(.secondarySystemBackground)).opacity(tint != nil ? 0.18 : 1))
        .clipShape(Capsule())
    }

    private var tripThemes: [String] {
        item.itinerary.itinerary.trip_summary.preferences?.themes?
            .map { $0.capitalized } ?? []
    }
    private var dateStatusText: String {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.startOfDay(for: item.startDate)
        let end   = Calendar.current.startOfDay(for: item.endDate)
        if end < today    { return "Completed" }
        if start <= today { return "Ongoing"   }
        return "Upcoming"
    }
}

private struct SwipeActionButtonsMockup: View {
    private let deepGreen = Color(hex: "0B6B3A")

    var body: some View {
        HStack(spacing: 18) {
            mockButton(icon: "trash", title: "Delete", tint: .red)
            mockButton(icon: "square.and.arrow.up", title: "Share", tint: deepGreen)
        }
        .padding(30)
        .background(Color.white)
    }

    private func mockButton(icon: String, title: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.6), tint.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.18), radius: 8, x: 0, y: 4)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
        }
    }
}

//#Preview("Swipe Action Buttons") {
   // SwipeActionButtonsMockup()
//}

#Preview {
    ScheduleView()
}
