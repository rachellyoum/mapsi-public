import SwiftUI

struct DatePageView: View {
    @ObservedObject var vm: TripDraftViewModel
    @Binding var showPlanning: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var goToGroup = false
    @State private var activeTimePicker: TimeTarget?
    private let defaultStartHour = 10
    private let defaultEndHour = 20
    private let defaultEndMinute = 0
    private let maxTripLengthDays = 7

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    dateQuestionHeader

                    MonthCalendarView(
                        displayedMonth: $vm.displayedMonth,
                        startDate: $startDate,
                        endDate: $endDate,
                        isSelectingEnd: $vm.isSelectingEnd,
                        minSelectableDate: minSelectableDate
                    )

                    dateInfoSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }

            VStack {
                PrimaryButton(
                    title: "NEXT",
                    isEnabled: startDate != nil && endDate != nil && isWithinAllowedRange
                ) {
                    vm.setDates(start: startDate, end: endDate)
                    goToGroup = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 44)
            .background(Color.white.ignoresSafeArea(edges: .bottom))
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("Select your dates")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomBackButton {
                    dismiss()
                }
            }
        }
        .navigationDestination(isPresented: $goToGroup) {
            GroupSelectionView(vm: vm, showPlanning: $showPlanning)
        }
        .onAppear {
            startDate = normalizedStartDate(vm.draft.startDate)
            endDate = clampedEndDate(normalizedEndDate(vm.draft.endDate, start: startDate), start: startDate)
            vm.setDates(start: startDate, end: endDate)
        }
        .onChange(of: startDate) { _, newValue in
            startDate = normalizedStartDate(newValue)
            endDate = clampedEndDate(normalizedEndDate(endDate, start: startDate), start: startDate)
            vm.setDates(start: startDate, end: endDate)
        }
        .onChange(of: endDate) { _, newValue in
            endDate = clampedEndDate(normalizedEndDate(newValue, start: startDate), start: startDate)
            vm.setDates(start: startDate, end: endDate)
        }
        .sheet(item: $activeTimePicker) { target in
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker(
                        "",
                        selection: target == .start ? startTimeBinding : endTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.top, 20)

                    Spacer()
                }
                .navigationTitle(target == .start ? "Select start time" : "Select end time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            activeTimePicker = nil
                        }
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }

    private enum TimeTarget: String, Identifiable {
        case start
        case end

        var id: String { rawValue }
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: {
                normalizedStartDate(startDate) ?? roundedUpOneHourFromNow()
            },
            set: { newValue in
                guard let current = startDate else { return }
                let day = Calendar.current.startOfDay(for: current)
                let merged = applyingTime(from: newValue, to: day) ?? newValue
                startDate = normalizedStartDate(merged)
                endDate = clampedEndDate(normalizedEndDate(endDate, start: startDate), start: startDate)
                vm.setDates(start: startDate, end: endDate)
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: {
                normalizedEndDate(endDate, start: startDate) ?? (startDate ?? roundedUpOneHourFromNow())
            },
            set: { newValue in
                guard let current = endDate else { return }
                let day = Calendar.current.startOfDay(for: current)
                let merged = applyingTime(from: newValue, to: day) ?? newValue
                endDate = clampedEndDate(normalizedEndDate(merged, start: startDate), start: startDate)
                vm.setDates(start: startDate, end: endDate)
            }
        )
    }

    private var minSelectableDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var maximumSelectableEndDate: Date? {
        guard let startDate else { return nil }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        return calendar.date(byAdding: .day, value: maxTripLengthDays - 1, to: startDay)
    }

    private var isWithinAllowedRange: Bool {
        guard let startDate, let endDate else { return false }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        guard let maxEndDay = maximumSelectableEndDate else { return false }
        return endDay >= startDay && endDay <= maxEndDay
    }

    private var startTimeText: String {
        formattedTime(normalizedStartDate(startDate))
    }

    private var endTimeText: String {
        formattedTime(normalizedEndDate(endDate, start: startDate))
    }

    private func normalizedStartDate(_ date: Date?) -> Date? {
        guard let date else { return nil }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        guard day >= today else { return nil }

        let defaultStart = calendar.date(bySettingHour: defaultStartHour, minute: 0, second: 0, of: day)
        let merged = applyingTime(from: date, to: day) ?? defaultStart

        if calendar.isDate(day, inSameDayAs: today) {
            return maxDate(merged, roundedUpOneHourFromNow())
        }

        return merged
    }

    private func normalizedEndDate(_ date: Date?, start: Date?) -> Date? {
        guard let date else { return nil }

        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        guard day >= today else { return nil }

        let defaultEnd = calendar.date(
            bySettingHour: defaultEndHour,
            minute: defaultEndMinute,
            second: 0,
            of: day
        )

        var result = applyingTime(from: date, to: day) ?? defaultEnd

        if calendar.isDate(day, inSameDayAs: today) {
            result = maxDate(result, roundedUpOneHourFromNow())
        }

        if let start,
           day == calendar.startOfDay(for: start),
           let result,
           result < start {
            return start
        }

        return clampedEndDate(result, start: start)
    }

    private func clampedEndDate(_ date: Date?, start: Date?) -> Date? {
        guard let date else { return nil }
        guard let start else { return date }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: date)

        if endDay < startDay {
            return start
        }

        guard let maxEndDay = calendar.date(byAdding: .day, value: maxTripLengthDays - 1, to: startDay) else {
            return date
        }

        if endDay > maxEndDay {
            return applyingTime(from: date, to: maxEndDay) ?? maxEndDay
        }

        return date
    }

    private func applyingTime(from source: Date, to day: Date) -> Date? {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: source)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: day
        )
    }

    private func roundedUpOneHourFromNow() -> Date {
        let calendar = Calendar.current
        let oneHourLater = Date().addingTimeInterval(3600)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: oneHourLater)

        let roundedHour = (components.minute ?? 0) > 0 ? (components.hour ?? 0) + 1 : (components.hour ?? 0)

        return calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: roundedHour,
                minute: 0,
                second: 0
            )
        ) ?? oneHourLater
    }

    private func formattedTime(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?): return max(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    private var dateQuestionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("When are you leaving?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)

            Text("* Up to 7 days")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(hex: "5C8DFF"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            dateRow(
                title: "Start",
                dateText: formattedDate(startDate),
                timeText: startTimeText,
                timeEnabled: startDate != nil,
                onTapTime: {
                    activeTimePicker = .start
                }
            )

            dateRow(
                title: "End",
                dateText: formattedDate(endDate),
                timeText: endTimeText,
                timeEnabled: endDate != nil,
                onTapTime: {
                    activeTimePicker = .end
                }
            )
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 22)
        .background(Color.white)
    }

    private func dateRow(
        title: String,
        dateText: String,
        timeText: String,
        timeEnabled: Bool,
        onTapTime: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.gray)
                .padding(-5)
            HStack(alignment: .center) {
                Text(dateText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.black)

                Spacer()

                timeChip(text: timeText, isEnabled: timeEnabled, action: onTapTime)
            }
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Select date" }
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd (E)"
        return f.string(from: date)
    }

    private func timeChip(text: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "0B6B3A"),
                                Color(hex: "22C07A")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.92))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "B7E7CC"),
                                        Color(hex: "8FD8B4")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

#Preview {
    NavigationStack {
        DatePageView(
            vm: {
                let vm = TripDraftViewModel(userId: "preview-user")
                vm.displayedMonth = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? Date()
                vm.setDates(
                    start: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 19)),
                    end: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 21))
                )
                return vm
            }(),
            showPlanning: .constant(true)
        )
    }
}
