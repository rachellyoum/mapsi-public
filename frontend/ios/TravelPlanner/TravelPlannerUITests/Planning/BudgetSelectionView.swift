import SwiftUI
import FirebaseAuth
import Foundation

private struct LoadingPerformanceTimer {
    private let startedAt = Date()
    private var checkpoints: [(name: String, elapsed: TimeInterval)] = []

    mutating func mark(_ name: String) {
        checkpoints.append((name: name, elapsed: Date().timeIntervalSince(startedAt)))
    }

    func summary(label: String) -> String {
        var lines: [String] = []
        lines.append("⏱️ [\(label)] Total: \(Self.format(Date().timeIntervalSince(startedAt)))")

        var previous: TimeInterval = 0
        for checkpoint in checkpoints {
            let segment = checkpoint.elapsed - previous
            lines.append("   • \(checkpoint.name): +\(Self.format(segment)) (cumulative \(Self.format(checkpoint.elapsed)))")
            previous = checkpoint.elapsed
        }

        return lines.joined(separator: "\n")
    }

    private static func format(_ interval: TimeInterval) -> String {
        String(format: "%.3fs", interval)
    }
}

struct BudgetSelectionView: View {
    @ObservedObject var vm: TripDraftViewModel
    @Binding var showPlanning: Bool

    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var submitResponse: GenerateTripResponse? = nil
    @State private var showResult = false
    @State private var latestTimingLog: String? = nil
    
    @EnvironmentObject private var router: AppRouter

    private let options: [(title: String, value: Double)] = [
        ("<500", 500),
        ("500 - 1000", 1000),
        ("1000 - 3000", 3000),
        ("3000 - 5000", 5000),
        (">5000", 7000)
    ]

    private var selectedBudgetTitle: String? {
        switch vm.draft.budgetTotal {
        case 500: return "<500"
        case 1000: return "500 - 1000"
        case 3000: return "1000 - 3000"
        case 5000: return "3000 - 5000"
        case 7000: return ">5000"
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("What is your budget?")
                                .font(.system(size: 16, weight: .semibold))

                            Text("* In CAD dollars")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "5C8DFF"))
                        }
                        VStack(spacing: 12) {
                            ForEach(options, id: \.title) { option in
                                OptionRow(
                                    title: option.title,
                                    isSelected: selectedBudgetTitle == option.title
                                ) {
                                    vm.setBudgetTotal(option.value)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                VStack(spacing: 10) {
                    PrimaryButton(
                        title: "GENERATE TRIP",
                        isEnabled: selectedBudgetTitle != nil && !isSubmitting
                    ) {
                        Task {
                            await submitTrip()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomBackButton {
                    showPlanning = false
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.2), value: isSubmitting)
        .fullScreenCover(isPresented: $isSubmitting) {
            AirplaneLoadingOverlay()
        }
        .fullScreenCover(isPresented: $showResult) {
            if let response = submitResponse {
                NavigationStack {
                    TripResultView(
                        response: response,
                        selectedPlace: DestinationPlace(
                            city: vm.draft.destinationCity,
                            iata: vm.draft.destinationIATA,
                            country: vm.draft.destinationCountry
                        ),
                        mode: .generated,
                        onSaveTrip: {
                            saveCurrentTrip()
                        },
                        onGoHome: {
                            vm.resetDraft()
                            showResult = false
                            showPlanning = false
                            router.topTab = .explore
                            router.path = NavigationPath()
                        }
                    )
                }
            }
        }
        .alert("Failed to create trip", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: Binding(
            get: { latestTimingLog != nil },
            set: { if !$0 { latestTimingLog = nil } }
        )) {
            NavigationStack {
                ScrollView {
                    Text(latestTimingLog ?? "")
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
                .navigationTitle("Loading Time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            latestTimingLog = nil
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func submitTrip() async {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "You must be logged in."
            return
        }

        errorMessage = nil
        var timer = LoadingPerformanceTimer()
        isSubmitting = true

        if vm.draft.originAirport.isEmpty {
            vm.setOriginAirport("YVR")
        }

        do {
            let idToken = try await user.getIDToken(forcingRefresh: true)
            timer.mark("getIDToken")

            let draft = try await vm.createTripDraft(
                userId: user.uid,
                idToken: idToken
            )
            timer.mark("createTripDraft")

            let itinerary = try await vm.generateItinerary(
                tripId: draft.id,
                idToken: idToken
            )
            timer.mark("generateItinerary")

            let log = timer.summary(label: "BudgetSelectionView.submitTrip success")
            print(log)
            latestTimingLog = log

            submitResponse = itinerary
            showResult = true
        } catch TripDraftError.missingDates {
            errorMessage = "Start date or end date is missing."
        } catch APIClient.APIError.badStatus(let code, let data) {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown server error."
            errorMessage = "Server error (\(code)): \(serverMessage)"
        } catch APIClient.APIError.decodingFailed {
            errorMessage = "The server responded, but the app could not decode the result."
        } catch {
            errorMessage = error.localizedDescription
        }

        if latestTimingLog == nil {
            let failureLog = timer.summary(label: "BudgetSelectionView.submitTrip failed")
            print(failureLog)
            latestTimingLog = failureLog
        }
        isSubmitting = false
    }

    private func saveCurrentTrip() {
        guard let itinerary = submitResponse else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let scheduleItem = MyScheduleItem(
            id: itinerary.trip_id,
            city: vm.draft.destinationCity,
            country: vm.draft.destinationCountry,
            startDate: vm.draft.startDate ?? Date(),
            endDate: vm.draft.endDate ?? Date(),
            itinerary: itinerary
        )

        let key = "my_generated_trips_\(userId)"
        let existing = UserDefaults.standard.data(forKey: key)
        var trips = (try? JSONDecoder().decode([MyScheduleItem].self, from: existing ?? Data())) ?? []

        trips.insert(scheduleItem, at: 0)

        if let data = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

private struct AirplaneLoadingOverlay: View {
    @State private var rotate = false

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.90, blue: 1.0),
                    Color.white,
                    Color(red: 0.90, green: 0.96, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Color.black.opacity(0.05)
                .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 8)

            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: 180, height: 180)

            Circle()
                .trim(from: 0.08, to: 0.92)
                .stroke(
                    Color.blue.opacity(0.25),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 10])
                )
                .frame(width: 180, height: 180)

            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 180, height: 180)

                Image(systemName: "airplane")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.95))
                            .shadow(color: .blue.opacity(0.15), radius: 10, x: 0, y: 4)
                    )
                    .offset(y: -90)
                    .rotationEffect(.degrees(45))
            }
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .animation(
                .linear(duration: 2.2).repeatForever(autoreverses: false),
                value: rotate
            )

            VStack(spacing: 220) {
                Text("Creating your trip...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue.opacity(0.85))
                    .tracking(0.4)
            }
        }
        .presentationBackground(.clear)
        .allowsHitTesting(true)
        .onAppear {
            rotate = true
        }
    }
}
