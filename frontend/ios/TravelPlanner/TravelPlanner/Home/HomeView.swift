import SwiftUI

struct HomeView: View {
    @State private var selectedSavedTrip: MyScheduleItem? = nil
    @State private var showPlanning = false
    @State private var showFlight = false
    @EnvironmentObject private var router: AppRouter

    @StateObject private var profileVM = ProfileViewModel()
    @StateObject private var scheduleVM = MyScheduleViewModel()

    private let deepGreen = Color(hex: "064229")
    private let midGreen = Color(hex: "0B6B3A")
    private let mintGreen = Color(hex: "E7F4EC")
    private let softBackground = Color(hex: "F1F7F3")

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        headerSection
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, -2)

                        BannerView {
                            showFlight = true
                        }
                        .padding(.horizontal, 14)

                        trendingTripsBanner
                            .padding(.bottom, -18)


                        if !scheduleVM.trips.isEmpty {
                            savedScheduleSection
                        } else {
                            emptySchedulePreview
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                profileVM.startListening()
                scheduleVM.loadTrips()
            }
            .onDisappear {
                profileVM.stopListening()
            }
            .fullScreenCover(isPresented: $showPlanning) {
                PlanningView(showPlanning: $showPlanning)
                    .environmentObject(router)
            }
            .navigationDestination(isPresented: $showFlight) {
                FlightView()
            }
            .fullScreenCover(item: $selectedSavedTrip) { item in
                NavigationStack {
                    TripResultView(
                        response: item.itinerary,
                        selectedPlace: DestinationPlace(
                            city: item.city,
                            iata: "---",
                            country: item.country
                        ),
                        mode: .saved
                    )
                }
            }
        }
    }
}

private extension HomeView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MAPSI")
                .font(.custom("DynaPuff-Medium", size: 23))
                .foregroundStyle(.black)
                .padding(.bottom, 12)

            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Text("Hello")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.black)

                    Text(profileVM.user?.name ?? "Traveler")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.85)

                Spacer()

                Button {
                    // TODO: Open notifications screen
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 34, height: 34)
                            .shadow(color: deepGreen.opacity(0.05), radius: 6, x: 0, y: 3)

                        Image(systemName: "bell")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(deepGreen)
                            .frame(width: 34, height: 34)

                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .offset(x: -6, y: 6)
                    }
                }
                .buttonStyle(.plain)
            }

            Text("Plan smarter, travel easier.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }


    var planTripCard: some View {
        Button {
            showPlanning = true
        } label: {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start a new trip")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(deepGreen)

                    Text("Choose a destination, add must-visit places, and let MAPSI build your route.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.black.opacity(0.68))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text("Plan now")
                            .font(.system(size: 14, weight: .bold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(deepGreen)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.82))
                    )
                    .overlay(
                        Capsule()
                            .stroke(deepGreen.opacity(0.10), lineWidth: 1)
                    )
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.34))
                        .frame(width: 86, height: 86)

                    Circle()
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                        .frame(width: 86, height: 86)

                    Image(systemName: "map.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                }
            }
            .padding(22)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "EAF7EF"),
                        Color(hex: "CDEDDC"),
                        Color(hex: "9BD8B8")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: deepGreen.opacity(0.10), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    var trendingTripsBanner: some View {
        Button {
            showPlanning = true
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Trending Trips")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "14213D"))

                Text("Discover popular weekend trips and routes.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color(hex: "14213D").opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(1)

                Text("Explore now")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(deepGreen)
                    .underline()
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(Color(hex: "D5E8DC"))
        }
        .buttonStyle(.plain)
    }

    var savedScheduleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Schedule")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)

                    Text("\(scheduleVM.trips.count) saved trip\(scheduleVM.trips.count == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    NotificationCenter.default.post(
                        name: Notification.Name("SwitchToScheduleTab"),
                        object: nil
                    )
                } label: {
                    HStack(spacing: 5) {
                        Text("View all")
                            .font(.system(size: 13, weight: .semibold))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(deepGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.62))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(deepGreen.opacity(0.10), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(scheduleVM.trips) { item in
                        Button {
                            selectedSavedTrip = item
                        } label: {
                            HomeScheduleCardView(
                                item: item,
                                format: scheduleVM.format,
                                accentColor: deepGreen
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "E6F2EB"))
    }

    var emptySchedulePreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Schedule")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)

                Text("Your saved trips will appear here.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            planTripCard
        }
        .padding(.top, 24)
        .padding(.bottom, 28)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "E6F2EB"))
    }


    }


struct HomeScheduleCardView: View {
    let item: MyScheduleItem
    let format: (Date) -> String
    let accentColor: Color
    private let deepGreen = Color(hex: "064229")

    @State private var cityPhotoURL: String? = nil
    @State private var isLoadingCityPhoto = false

    private let mediaService = MediaService()

    private var tripDays: Int {
        let days = Calendar.current.dateComponents([.day], from: item.startDate, to: item.endDate).day ?? 0
        return days + 1
    }

    private var heroImageName: String {
        DestinationImageProvider.imageName(for: item.city, country: item.country)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cardImage
                .frame(width: 268, height: 292)
                .clipped()

            LinearGradient(
                colors: [
                    .black.opacity(0.06),
                    .black.opacity(0.12),
                    .black.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.city)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text(item.country)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                }

                HStack {
                    schedulePill(format(item.startDate))
                    Spacer()
                    schedulePill("\(tripDays)d")
                }
            }
            .padding(18)
        }
        .frame(width: 268, height: 292)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: deepGreen.opacity(0.12), radius: 14, x: 0, y: 8)
        .task {
            await loadCityPhotoIfNeeded()
        }
    }

    @ViewBuilder
    private var cardImage: some View {
        if let cityPhotoURL,
           let url = URL(string: cityPhotoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure(_):
                    fallbackImage

                case .empty:
                    ZStack {
                        fallbackImage
                        ProgressView()
                    }

                @unknown default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Image(heroImageName)
            .resizable()
            .scaledToFill()
    }

    private func schedulePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.20))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
            )
    }

    private func loadCityPhotoIfNeeded() async {
        guard cityPhotoURL == nil, !isLoadingCityPhoto else { return }
        isLoadingCityPhoto = true
        defer { isLoadingCityPhoto = false }

        do {
            cityPhotoURL = try await mediaService.fetchCityPhotoURL(city: item.city)
        } catch {
            cityPhotoURL = nil
        }
    }
}


#Preview {
    HomeView()
}
 

