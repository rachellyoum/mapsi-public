import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct TripResultView: View {
    enum Mode {
        case generated
        case saved
    }
    
    let response: GenerateTripResponse
    let selectedPlace: DestinationPlace
    let mode: Mode

    var onSaveTrip: (() -> Void)? = nil
    var onGoHome: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showSavedAlert = false
    @State private var cityPhotoURL: String? = nil
    @State private var itemPhotoURLs: [UUID: String] = [:]
    @State private var loadingPhotoItemIDs: Set<UUID> = []
    @State private var isLoadingCityPhoto = false
    @State private var selectedDetailItem: PlaceDetailItem? = nil
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedMapItemID: UUID? = nil
    @State private var isEditMode = false
    @State private var showAddStop = false
    @State private var addStopDay: Int? = nil
    @State private var draggedStop: DraggedStop? = nil
    @StateObject private var scheduleVM = MyScheduleViewModel()
    @StateObject private var vm = TripDetailViewModel()

    private let mediaService = MediaService()
    private let deepGreen = Color(hex: "0B6B3A")
    private let softMint = Color(hex: "EEF6F1")
    private let paleGreen = Color(hex: "DCEFE4")
    private let pageTop = Color(hex: "F8FBF8")
    private let pageBottom = Color(hex: "EDF5EF")
    private let cardShadow = Color(hex: "0B6B3A").opacity(0.08)
    private let glassFill = Color.white.opacity(0.58)
    private let glassStroke = Color.white.opacity(0.55)
    private let accentGreen = Color(hex: "1E8A57")
    private var itinerary: ItineraryPayload {
        vm.itinerary ?? response.itinerary
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        heroSection(width: screenWidth)
                            .frame(width: screenWidth)
                            .clipped()

                        mapSection(proxy: proxy)
                            .frame(width: screenWidth)
                            .clipped()

                        VStack(alignment: .leading, spacing: 24) {

                            if !itinerary.days.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(itinerary.days) { day in
                                        dayCard(day)
                                    }
                                }
                            }

                            if !itinerary.tips.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Tips")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.primary)
                                    Divider()

                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(itinerary.tips, id: \.self) { tip in
                                            HStack(alignment: .top, spacing: 10) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(deepGreen)
                                                    .font(.system(size: 15))

                                                Text(tip)
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                    .padding(18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .fill(Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(paleGreen, lineWidth: 1)
                                    )
                                    .shadow(color: cardShadow, radius: 10, x: 0, y: 5)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                        .frame(width: screenWidth, alignment: .leading)
                        .clipped()
                    }
                    .frame(width: screenWidth, alignment: .leading)
                    .clipped()
                }
            }
        }
        .background(
            LinearGradient(
                colors: [pageTop, pageBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if mode == .generated {
                    Button {
                        onSaveTrip?()
                        showSavedAlert = true
                    } label: {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(deepGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }

                if mode == .saved {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isEditMode.toggle()
                        }
                    } label: {
                        Text(isEditMode ? "Done" : "Edit")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(deepGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }

                Button {
                    handleClose()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)

                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .alert("Saved!", isPresented: $showSavedAlert) {
            Button("OK") {
                goHome()
            }
        } message: {
            Text("You can check it in My Schedule.")
        }
        .task {
            await loadCityPhoto()
            await refreshTripFromServer()
        }
        .sheet(isPresented: $showAddStop) {
            if let day = addStopDay {
                AddStopSheet(
                    tripId: response.trip_id,
                    dayNumber: day,
                    destinationCity: itinerary.trip_summary.destination,
                    scheduleVM: scheduleVM,
                    isPresented: $showAddStop,
                    onAdded: {
                        Task {
                            await refreshTripFromServer()
                        }
                    }
                )
            }
        }
        .onAppear {
            NotificationCenter.default.post(
                name: Notification.Name("HideCustomTabBar"),
                object: nil
            )
        }
        .onDisappear {
            NotificationCenter.default.post(
                name: Notification.Name("ShowCustomTabBar"),
                object: nil
            )
        }
        .navigationDestination(item: $selectedDetailItem) { detailItem in
            ResultDetailView(item: detailItem)
        }
    }

    @MainActor
    private func refreshTripFromServer() async {
        await vm.loadTrip(tripId: response.trip_id)
        updateMapPosition()
    }


    @MainActor
    private func swapStop(day: TripDay, index: Int, direction: Int) async {
        let targetIndex = index + direction

        print("SWAP BUTTON TAPPED")
        print("day:", day.day, "index:", index, "targetIndex:", targetIndex)

        guard day.items.indices.contains(index),
              day.items.indices.contains(targetIndex) else {
            print("SWAP CANCELLED: index out of range")
            return
        }

        let currentOrder = day.items[index].order ?? (index + 1)
        let targetOrder = day.items[targetIndex].order ?? (targetIndex + 1)

        print("SWAP REQUEST:", "tripId=\(response.trip_id)", "day=\(day.day)", "a=\(currentOrder)", "b=\(targetOrder)")

        await vm.swap(
            tripId: response.trip_id,
            day: day.day,
            a: currentOrder,
            b: targetOrder
        )

        await refreshTripFromServer()
    }



    private func handleClose() {
        switch mode {
        case .generated:
            goHome()   // 저장 없이 홈으로
        case .saved:
            dismiss()  // schedule에서 들어온 경우 이전 화면
        }
    }

    private func goHome() {
        print("goHome called")
        if let onGoHome {
            print("onGoHome exists")
            onGoHome()
        } else {
            print("onGoHome is nil, dismissing")
            dismiss()
        }
    }

    private func mapSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Route Overview")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(mapItems.count) stops around \(displayCity)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }

            }

            Map(position: $mapPosition) {
                ForEach(mapItems) { stop in
                    Annotation(stop.item.place_name, coordinate: stop.coordinate) {
                        Button {
                            selectedMapItemID = stop.id
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(stop.id, anchor: .center)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(dayColor(for: stop.dayNumber))
                                        .frame(width: 34, height: 34)
                                        .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)

                                    Circle()
                                        .stroke(selectedMapItemID == stop.id ? Color.white : Color.clear, lineWidth: 2)
                                        .frame(width: 34, height: 34)

                                    Text("\(stop.stopNumber)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }

                                Text(stop.item.place_name)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(dayColor(for: stop.dayNumber))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: 90)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 245)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: cardShadow, radius: 14, x: 0, y: 8)
        .padding(.horizontal, 0)
        .padding(.top, -2)
    }

    private var mapItems: [MapStop] {
        itinerary.days.enumerated().flatMap { dayOffset, day in
            day.items.enumerated().compactMap { itemOffset, item in
                guard let coordinate = item.coordinate,
                      CLLocationCoordinate2DIsValid(coordinate) else {
                    return nil
                }

                return MapStop(
                    id: item.id,
                    item: item,
                    dayNumber: dayOffset + 1,
                    stopNumber: itemOffset + 1,
                    coordinate: coordinate
                )
            }
        }
    }

    private func updateMapPosition() {
        let coordinates = mapItems.map(\.coordinate)
        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1, let coordinate = coordinates.first {
            mapPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                )
            )
            return
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLng = longitudes.min(),
              let maxLng = longitudes.max() else {
            return
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.03),
            longitudeDelta: max((maxLng - minLng) * 1.6, 0.03)
        )

        mapPosition = .region(
            MKCoordinateRegion(center: center, span: span)
        )
    }
    @ViewBuilder
    private func placeThumbnail(for item: TripItem) -> some View {
        let resolvedPhotoURL = itemPhotoURLs[item.id]

        if let resolvedPhotoURL,
           !resolvedPhotoURL.isEmpty,
           let url = URL(string: resolvedPhotoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(softMint)
                        .frame(width: 92, height: 92)
                        .overlay {
                            ProgressView()
                        }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 92)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                case .failure:
                    placeThumbnailFallback()

                @unknown default:
                    placeThumbnailFallback()
                }
            }
            .task {
                if itemPhotoURLs[item.id] == nil {
                    await loadPhoto(for: item)
                }
            }
        } else {
            placeThumbnailFallback()
                .task {
                    if itemPhotoURLs[item.id] == nil {
                        await loadPhoto(for: item)
                    }
                }
        }
    }
    
    private func placeThumbnailFallback() -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(softMint)
            .frame(width: 90, height: 90)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(deepGreen.opacity(0.6))
            }
    }
    
    private func placeCard(for item: TripItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                placeThumbnail(for: item)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.place_name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 6) {
                    if let type = item.type, !type.isEmpty {
                        Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if let rating = item.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)

                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let hours = item.opening_hours, !hours.isEmpty {
                        Text(hours)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accentGreen)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let stopPriceText = priceRangeText(item.stop_price_level), !stopPriceText.isEmpty {
                        Text(stopPriceText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.9))
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let price = item.price_level, !priceLevelText(price).isEmpty {
                        Text(priceLevelText(price))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.9))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            placeGlassCard
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(selectedMapItemID == item.id ? accentGreen : .clear, lineWidth: 2)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .id(item.id)
    }
    
    private func displayCategory(from type: String?) -> String {
        guard let type, !type.isEmpty else { return "Place" }

        switch type.lowercased() {
        case "restaurant": return "Restaurant"
        case "cafe": return "Cafe"
        case "tourist_attraction": return "Attraction"
        case "museum": return "Museum"
        case "park": return "Park"
        case "shopping_mall": return "Shopping"
        default:
            return type
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    private func priceLevelText(_ level: Int) -> String {
        guard level > 0 else { return "" }
        return String(repeating: "$", count: level)
    }
    private func priceRangeText(_ range: PriceLevelRange?) -> String? {
        guard let range else { return nil }

        let currency = (range.currency ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let minValue = range.min
        let maxValue = range.max

        let prefix = currency.isEmpty ? "$" : "\(currency) "

        switch (minValue, maxValue) {
        case let (min?, max?):
            if min == max {
                return "\(prefix)\(Int(min.rounded()))"
            }
            return "\(prefix)\(Int(min.rounded())) - \(Int(max.rounded()))"
        case let (min?, nil):
            return "From \(prefix)\(Int(min.rounded()))"
        case let (nil, max?):
            return "Up to \(prefix)\(Int(max.rounded()))"
        default:
            return nil
        }
    }
    
    private func formattedOpeningHours(for item: TripItem) -> String {
        if let hours = item.opening_hours, !hours.isEmpty {
            return hours
        }
        return "Hours unavailable"
    }
    
    private func loadPhoto(for item: TripItem) async {
        guard itemPhotoURLs[item.id] == nil else { return }
        guard !loadingPhotoItemIDs.contains(item.id) else { return }

        loadingPhotoItemIDs.insert(item.id)
        defer { loadingPhotoItemIDs.remove(item.id) }

        let query = "\(item.place_name) \(displayCity)"

        do {
            let url = try await mediaService.fetchCityPhotoURL(city: query)
            itemPhotoURLs[item.id] = url
        } catch {
            print("Failed to load item photo for \(item.place_name):", error.localizedDescription)
            itemPhotoURLs[item.id] = ""
        }
    }
    // MARK: - Hero

    private func heroSection(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            heroBackground(width: width)

            VStack(alignment: .leading, spacing: 12) {
                Text("Your Next Journey")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))

                Text(itinerary.trip_summary.destination)
                    .font(.system(size: 30, weight: .bold))
                    .minimumScaleFactor(0.78)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        heroTag(text: "\(itinerary.trip_summary.days ?? 0) days")
                        heroTag(text: selectedPlace.country)

                        if let vibe = itinerary.trip_summary.vibe, !vibe.isEmpty {
                            heroTag(text: vibe)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .frame(width: width, alignment: .leading)
        }
        .frame(width: width, height: 320)
        .background(softMint)
        .clipShape(Rectangle())
        .contentShape(Rectangle())
        .padding(.top, 8)
    }

    private func fallbackHeroImage(width: CGFloat) -> some View {
        Image(heroImageName)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: 320)
            .clipped()
            .overlay(gradientOverlay)
    }

    private var gradientOverlay: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.05),
                .black.opacity(0.15),
                .black.opacity(0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    @ViewBuilder
    private func heroBackground(width: CGFloat) -> some View {
        if let cityPhotoURL,
           let url = URL(string: cityPhotoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    fallbackHeroImage(width: width)
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: 320)
                        .clipped()
                        .overlay(gradientOverlay)

                case .failure:
                    fallbackHeroImage(width: width)

                @unknown default:
                    fallbackHeroImage(width: width)
                }
            }
        } else {
            fallbackHeroImage(width: width)
        }
    }
    
    private func loadCityPhoto() async {
        guard !displayCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if isLoadingCityPhoto || cityPhotoURL != nil { return }
        isLoadingCityPhoto = true
        defer { isLoadingCityPhoto = false }

        do {
            cityPhotoURL = try await mediaService.fetchCityPhotoURL(city: displayCity)
        } catch {
            print("Failed to load city photo:", error.localizedDescription)
            cityPhotoURL = nil
        }
    }
    
    private var displayCity: String {
        selectedPlace.city.isEmpty ? itinerary.trip_summary.destination : selectedPlace.city
    }
    

    private func heroTag(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 220, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.16))
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
    // MARK: - Day Card
    
    private func dayCard(_ day: TripDay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            dayHeader(for: day)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(day.items.enumerated()), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: 10) {
                        if let timeBlock = item.time_block,
                           !timeBlock.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(formattedTimeBlock(timeBlock))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(accentGreen)
                                .padding(.leading, isEditMode ? 8 : 42)
                        }

                        if isEditMode {
                            // Edit mode: show controls + place row
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(deepGreen.opacity(0.75))
                                    .frame(width: 32, height: 44)
                                    .background(deepGreen.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                itineraryPlaceRow(
                                    item: item,
                                    index: index + 1,
                                    isLast: index == day.items.count - 1
                                )
                                .frame(maxWidth: .infinity)

                                // Delete button
                                Button {
                                    let order = item.order ?? (index + 1)
                                    print("DELETE BUTTON TAPPED")
                                    print("DELETE REQUEST:", "tripId=\(response.trip_id)", "day=\(day.day)", "order=\(order)")

                                    Task {
                                        await vm.delete(
                                            tripId: response.trip_id,
                                            day: day.day,
                                            order: order
                                        )
                                        await refreshTripFromServer()
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.red)
                                        .frame(width: 34, height: 34)
                                        .background(Color.red.opacity(0.10))
                                        .clipShape(Circle())
                                }
                            }
                            .contentShape(Rectangle())
                            .onDrag {
                                let order = item.order ?? (index + 1)
                                draggedStop = DraggedStop(day: day.day, order: order, itemID: item.id)
                                return NSItemProvider(object: item.id.uuidString as NSString)
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: StopDropDelegate(
                                    draggedStop: $draggedStop,
                                    targetDay: day.day,
                                    targetOrder: item.order ?? (index + 1),
                                    targetItemID: item.id,
                                    onSwap: { source, targetDay, targetOrder in
                                        guard source.day == targetDay,
                                              source.order != targetOrder else { return }

                                        Task {
                                            await vm.swap(
                                                tripId: response.trip_id,
                                                day: targetDay,
                                                a: source.order,
                                                b: targetOrder
                                            )
                                            await refreshTripFromServer()
                                        }
                                    }
                                )
                            )
                        } else {
                            Button {
                                selectedDetailItem = PlaceDetailItem(
                                    place_name: item.place_name,
                                    type: item.type,
                                    rating: item.rating,
                                    activity: item.activity,
                                    address: item.address,
                                    price_level: item.price_level,
                                    notes: item.notes,
                                    photo_url: itemPhotoURLs[item.id]
                                )
                            } label: {
                                itineraryPlaceRow(
                                    item: item,
                                    index: index + 1,
                                    isLast: index == day.items.count - 1
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if !isEditMode,
                           index < day.items.count - 1,
                           let travel = day.items[index + 1].travel_from_previous {
                            transportationRow(travel)
                                .padding(.leading, 42)
                        }
                    }
                }
            }

            // Add Stop button (edit mode only)
            if isEditMode {
                Button {
                    addStopDay = day.day
                    showAddStop = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add Stop")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(deepGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(deepGreen.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(deepGreen.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
    
    private func itineraryPlaceRow(item: TripItem, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 30, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(paleGreen, lineWidth: 1)
                        )
                        .shadow(color: cardShadow, radius: 6, x: 0, y: 3)

                    Text("\(index)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(deepGreen)
                }

                if !isLast {
                    Rectangle()
                        .fill(paleGreen)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 8)
                }
            }
            .frame(width: 28)

            placeCard(for: item)
                .allowsHitTesting(false)
        }
    }

    private func transportationPlaceholder() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tram.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(deepGreen)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(deepGreen.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Transportation")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Subway · 18 min")
                    .font(.system(size: 14, weight: .medium))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.tertiarySystemFill))
        )
    }
    

    private var dayHeaderGlassCard: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(glassStroke, lineWidth: 1)
            )
            .shadow(color: cardShadow, radius: 14, x: 0, y: 8)
    }
    
    private func formattedDateForDay(_ dayNumber: Int) -> String {
        guard let startDate = itinerary.trip_summary.startDateValue else {
            return ""
        }

        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: max(dayNumber - 1, 0), to: startDate) else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func dayHeader(for day: TripDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Day \(day.day)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                if !formattedDateForDay(day.day).isEmpty {
                    Text(formattedDateForDay(day.day))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(accentGreen)
                        .lineLimit(1)
                }

                Spacer()
            }

            Text(day.title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let dayPriceText = priceRangeText(day.day_price_level), !dayPriceText.isEmpty {
                Text(dayPriceText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentGreen)
            }

            Divider()
                .overlay(Color.black.opacity(0.08))
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }
    
    private var placeGlassCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(glassStroke, lineWidth: 1)
            )
            .shadow(color: cardShadow, radius: 12, x: 0, y: 6)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .bold))
    }

    private func formattedTimeBlock(_ value: String) -> String {
        switch value.lowercased() {
        case "morning": return "Morning"
        case "afternoon": return "Afternoon"
        case "evening": return "Evening"
        case "night": return "Night"
        default: return value.capitalized
        }
    }

    private func transportationRow(_ travel: TravelFromPrevious) -> some View {
        HStack(spacing: 10) {
            Image(systemName: transportIcon(for: travel.recommended_mode))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentGreen)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(softMint)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(transportModeText(travel.recommended_mode))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(transportSummary(travel))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(paleGreen, lineWidth: 1)
        )
    }

    private func transportIcon(for mode: String?) -> String {
        switch (mode ?? "").uppercased() {
        case "DRIVE": return "car.fill"
        case "TRANSIT": return "tram.fill"
        case "WALK": return "figure.walk"
        default: return "location.fill"
        }
    }

    private func transportModeText(_ mode: String?) -> String {
        switch (mode ?? "").uppercased() {
        case "DRIVE": return "Drive"
        case "TRANSIT": return "Transit"
        case "WALK": return "Walk"
        default: return "Move"
        }
    }

    private func transportSummary(_ travel: TravelFromPrevious) -> String {
        var parts: [String] = []

        if let duration = travel.recommended_duration_min {
            parts.append("\(Int(duration.rounded())) min")
        }

        if let distance = travel.distance_meters {
            if distance >= 1000 {
                parts.append(String(format: "%.1f km", distance / 1000))
            } else {
                parts.append("\(Int(distance.rounded())) m")
            }
        }

        return parts.isEmpty ? "Transportation info unavailable" : parts.joined(separator: " · ")
    }

    private var heroImageName: String {
        DestinationImageProvider.imageName(
            for: selectedPlace.city.isEmpty ? itinerary.trip_summary.destination : selectedPlace.city,
            country: selectedPlace.country
        )
    }
    private struct MapStop: Identifiable {
        let id: UUID
        let item: TripItem
        let dayNumber: Int
        let stopNumber: Int
        let coordinate: CLLocationCoordinate2D
    }

    private func dayColor(for dayNumber: Int) -> Color {
        let palette: [Color] = [
            .blue,
            .green,
            .orange,
            .purple,
            .pink,
            .red,
            .teal,
            .indigo
        ]
        return palette[(dayNumber - 1) % palette.count]
    }
    struct DraggedStop: Equatable {
        let day: Int
        let order: Int
        let itemID: UUID
    }
}

private struct StopDropDelegate: DropDelegate {
    @Binding var draggedStop: TripResultView.DraggedStop?
    let targetDay: Int
    let targetOrder: Int
    let targetItemID: UUID
    let onSwap: (TripResultView.DraggedStop, Int, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        guard let draggedStop else { return false }
        return draggedStop.day == targetDay && draggedStop.itemID != targetItemID
    }

    func dropEntered(info: DropInfo) {
        guard let draggedStop,
              draggedStop.day == targetDay,
              draggedStop.itemID != targetItemID else { return }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedStop,
              draggedStop.day == targetDay,
              draggedStop.itemID != targetItemID else {
            self.draggedStop = nil
            return false
        }

        onSwap(draggedStop, targetDay, targetOrder)
        self.draggedStop = nil
        return true
    }

    func dropExited(info: DropInfo) {}
}
#Preview("Generated Mode") {
    NavigationStack {
        TripResultView(
            response: GenerateTripResponse.mock,
            selectedPlace: DestinationPlace.mock,
            mode: .generated,
            onSaveTrip: {},
            onGoHome: {}
        )
    }
}

#Preview("Saved Mode") {
    NavigationStack {
        TripResultView(
            response: GenerateTripResponse.mock,
            selectedPlace: DestinationPlace.mock,
            mode: .saved
        )
    }
}

// MARK: - Mock Data

extension GenerateTripResponse {
    static let mock = GenerateTripResponse(
        trip_id: "mock-trip-id",
        itinerary: ItineraryPayload.mock,
        cached: false
    )
}

extension DestinationPlace {
    static let mock = DestinationPlace(
        city: "Paris",
        iata: "CDG",
        country: "France"
    )
}

extension ItineraryPayload {
    static let mock = ItineraryPayload(
        trip_summary: TripSummary.mock,
        days: [
            TripDay.day1,
            TripDay.day2
        ],
        tips: [
            "Book major attractions in advance.",
            "Use public transit to save time.",
            "Keep some time for walking and photos."
        ]
    )
}

extension TripSummary {
    static let mock = TripSummary(
        destination: "Paris",
        days: 2,
        vibe: "Romantic",
        total_price_level: PriceLevelRange(
            currency: "CAD",
            min: 0,
            max: 200
            )
        )
}

extension TripDay {
    static let day1 = TripDay(
        day: 1,
        title: "Classic Highlights",
        items: [
            TripItem.item1,
            TripItem.item2,
            TripItem.item3
        ]
    )

    static let day2 = TripDay(
        day: 2,
        title: "Art and Local Streets",
        items: [
            TripItem.item4,
            TripItem.item5
        ]
    )
}

extension TripItem {
    static let item1 = TripItem(
        order: 1,
        time_block: "morning",
        place_name: "Eiffel Tower",
        lat: 48.8584,
        lng: 2.2945,
        type: "tourist_attraction",
        place_id: "mock-eiffel",
        opening_hours: "09:30 - 23:45",
        rating: 4.7,
        activity: "Visit Eiffel Tower",
        address: "Champ de Mars, 5 Avenue Anatole France, Paris",
        price_level: nil,
        notes: "Start early to avoid crowds.",
        travel_from_previous: nil
    )

    static let item2 = TripItem(
        order: 2,
        time_block: "afternoon",
        place_name: "Louvre Museum",
        lat: 48.8606,
        lng: 2.3376,
        type: "museum",
        place_id: "mock-louvre",
        opening_hours: "09:00 - 18:00",
        rating: 4.8,
        activity: "Explore the museum highlights",
        address: "Rue de Rivoli, Paris",
        price_level: 3,
        notes: "Visit the key galleries first.",
        travel_from_previous: TravelFromPrevious(
            recommended_mode: "TRANSIT",
            recommended_duration_min: 18,
            recommended_reason: "Fastest route",
            distance_meters: 3200,
            polyline: nil,
            options: [
                TravelOption(mode: "TRANSIT", available: true, duration_min: 18, distance_meters: 3200, polyline: nil),
                TravelOption(mode: "WALK", available: true, duration_min: 42, distance_meters: 3100, polyline: nil)
            ]
        )
    )

    static let item3 = TripItem(
        order: 3,
        time_block: "evening",
        place_name: "Seine River Cruise",
        lat: 48.8629,
        lng: 2.2870,
        type: "tourist_attraction",
        place_id: "mock-seine",
        opening_hours: "10:00 - 22:00",
        rating: 4.5,
        activity: "Take an evening cruise",
        address: "Port de la Bourdonnais, Paris",
        price_level: 2,
        notes: "Best around sunset.",
        travel_from_previous: TravelFromPrevious(
            recommended_mode: "DRIVE",
            recommended_duration_min: 16,
            recommended_reason: "Best for evening timing",
            distance_meters: 4100,
            polyline: nil,
            options: [
                TravelOption(mode: "DRIVE", available: true, duration_min: 16, distance_meters: 4100, polyline: nil),
                TravelOption(mode: "TRANSIT", available: true, duration_min: 24, distance_meters: 4100, polyline: nil)
            ]
        )
    )

    static let item4 = TripItem(
        order: 1,
        time_block: "morning",
        place_name: "Montmartre",
        lat: 48.8867,
        lng: 2.3431,
        type: "tourist_attraction",
        place_id: "mock-montmartre",
        opening_hours: "00:00 - 23:59",
        rating: 4.6,
        activity: "Walk around Montmartre",
        address: "Montmartre, Paris",
        price_level: nil,
        notes: "Great cafés and beautiful streets.",
        travel_from_previous: nil
    )

    static let item5 = TripItem(
        order: 2,
        time_block: "afternoon",
        place_name: "Musée d'Orsay",
        lat: 48.8600,
        lng: 2.3266,
        type: "museum",
        place_id: "mock-orsay",
        opening_hours: "09:30 - 18:00",
        rating: 4.7,
        activity: "See Impressionist masterpieces",
        address: "1 Rue de la Légion d'Honneur, Paris",
        price_level: 3,
        notes: "Perfect for Impressionist art lovers.",
        travel_from_previous: TravelFromPrevious(
            recommended_mode: "TRANSIT",
            recommended_duration_min: 22,
            recommended_reason: "Easy metro route",
            distance_meters: 3900,
            polyline: nil,
            options: [
                TravelOption(mode: "TRANSIT", available: true, duration_min: 22, distance_meters: 3900, polyline: nil),
                TravelOption(mode: "WALK", available: true, duration_min: 48, distance_meters: 3600, polyline: nil)
            ]
        )
    )
}

private extension TripSummary {
    var startDateValue: Date? {
        nil
    }
}

private extension TripItem {
    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}
