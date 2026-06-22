//
//  UIComponent.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-04.
//

import SwiftUI

// MARK: - OptionRow
struct OptionRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color(hex: "1F5C47") : Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 18, height: 18)

                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "1F5C47"),
                                        Color(hex: "5E9F84")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 10, height: 10)
                    }
                }

                Text(title)
                    .foregroundStyle(.primary)
                    .font(.system(size: 15, weight: .regular))

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PrimaryButton
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                isEnabled
                                ? LinearGradient(
                                    colors: [
                                        Color(hex: "1F5C47"),
                                        Color(hex: "4F8F74")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color(hex: "1F5C47").opacity(0.3),
                                        Color(hex: "5E9F84").opacity(0.25)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(isEnabled ? 0.03 : 0.02))

                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
                )
                .shadow(color: isEnabled ? Color(hex: "0B6B3A").opacity(0.25) : .clear, radius: 10, x: 0, y: 6)
        }
    }
}
// MARK: - CustomBackButton
struct CustomBackButton: View {
    var action: () -> Void

    private let deepGreen = Color(hex: "064229")
    private let midGreen = Color(hex: "0B6B3A")
    private let lightGreen = Color(hex: "22C07A")

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 34, height: 34)

                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                    .frame(width: 34, height: 34)

                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MonthCalendarView
struct MonthCalendarView: View {
    @Binding var displayedMonth: Date
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var isSelectingEnd: Bool
    let minSelectableDate: Date
    let maxTripLengthDays: Int = 7

    private let cal = Calendar.current

    private func isDisabled(_ date: Date) -> Bool {
        let normalizedDate = startOfDay(date)

        if normalizedDate < startOfDay(minSelectableDate) {
            return true
        }

        if let start = startDate.map(startOfDay), endDate == nil {
            guard let maxEndDate = cal.date(byAdding: .day, value: maxTripLengthDays - 1, to: start) else {
                return false
            }
            return normalizedDate > maxEndDate
        }

        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 12)
                .padding(.bottom, 14)

            Divider()

            weekdaysRow
                .padding(.top, 14)
                .padding(.bottom, 10)

            calendarGrid
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
        }
        .background(Color.white)
    }

    private var header: some View {
        HStack {
            Button {
                displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.gray.opacity(0.65))
                    .frame(width: 32, height: 32)
            }

            Spacer()

            Text(monthTitle(displayedMonth))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.black)

            Spacer()

            Button {
                displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 18)
    }

    private var weekdaysRow: some View {
        let symbols = cal.shortWeekdaySymbols

        return HStack {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(weekdayColor(index: index))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
    }

    private var calendarGrid: some View {
        let days = daysInMonthGrid(for: displayedMonth)

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: 6
        ) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                dayCell(day)
                    .frame(height: 42)
            }
        }
    }

    private func dayCell(_ day: Date?) -> some View {
        let text = day.map { "\(cal.component(.day, from: $0))" } ?? ""

        let isInRange = isDateInSelectedRange(day)
        let isStart = isSameDay(day, startDate)
        let isEnd = isSameDay(day, endDate)
        let weekday = day.map { cal.component(.weekday, from: $0) }
        let isDisabledDate = day.map(isDisabled) ?? true

        return Button {
            guard let day else { return }
            guard !isDisabled(day) else { return }
            select(day)
        } label: {
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(
                    ZStack {
                        if isInRange && !(isStart || isEnd) {
                            Circle()
                                .fill(Color(hex: "DDF3E6"))
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: "A9DFC1"), lineWidth: 0.8)
                                )
                        }

                        if isStart || isEnd {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "2F6F57"),
                                            Color(hex: "6FAF92")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                )
                .foregroundStyle(isDisabledDate ? Color.gray.opacity(0.6) : dayTextColor(isStart: isStart, isEnd: isEnd, weekday: weekday))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(day == nil || isDisabledDate)
        .opacity(day == nil ? 0 : (isDisabledDate ? 0.9 : 1))
    }

    private func select(_ day: Date) {
        let selectedDay = startOfDay(day)

        if startDate == nil || (startDate != nil && endDate != nil) {
            startDate = mergedDate(for: selectedDay, preserving: startDate, defaultHour: 10, defaultMinute: 0)
            endDate = nil
            isSelectingEnd = true
            return
        }

        guard let start = startDate.map(startOfDay) else { return }

        if selectedDay == start {
            startDate = nil
            endDate = nil
            isSelectingEnd = false
            return
        }

        if selectedDay < start {
            let previousStart = startDate
            startDate = mergedDate(for: selectedDay, preserving: previousStart, defaultHour: 10, defaultMinute: 0)
            endDate = mergedDate(for: start, preserving: endDate, defaultHour: 20, defaultMinute: 0)
        } else {
            let maxAllowedEnd = cal.date(byAdding: .day, value: maxTripLengthDays - 1, to: start) ?? selectedDay
            let clampedEndDay = min(selectedDay, maxAllowedEnd)
            endDate = mergedDate(for: clampedEndDay, preserving: endDate, defaultHour: 20, defaultMinute: 0)
        }

        isSelectingEnd = false
    }

    private func isDateInSelectedRange(_ day: Date?) -> Bool {
        guard let day = day.map(startOfDay), let start = startDate.map(startOfDay) else {
            return false
        }

        if let end = endDate.map(startOfDay) {
            return day >= start && day <= end
        }

        return day == start
    }

    private func isSameDay(_ lhs: Date?, _ rhs: Date?) -> Bool {
        guard let lhs, let rhs else { return false }
        return cal.isDate(lhs, inSameDayAs: rhs)
    }

    private func dayTextColor(isStart: Bool, isEnd: Bool, weekday: Int?) -> Color {
        if isStart || isEnd { return .white }
        if weekday == 1 { return Color.red.opacity(0.75) }
        if weekday == 7 { return Color.blue.opacity(0.75) }
        return Color.gray.opacity(0.95)
    }

    private func weekdayColor(index: Int) -> Color {
        if index == 0 { return Color.red.opacity(0.75) }
        if index == 6 { return Color.blue.opacity(0.75) }
        return Color.gray.opacity(0.85)
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }

    private func mergedDate(for day: Date, preserving original: Date?, defaultHour: Int, defaultMinute: Int) -> Date {
        if let original, let merged = applyingTime(from: original, to: day) {
            return merged
        }

        return cal.date(
            bySettingHour: defaultHour,
            minute: defaultMinute,
            second: 0,
            of: day
        ) ?? day
    }

    private func applyingTime(from source: Date, to day: Date) -> Date? {
        let time = cal.dateComponents([.hour, .minute], from: source)
        return cal.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day)
    }

    private func startOfDay(_ date: Date) -> Date {
        cal.startOfDay(for: date)
    }

    private func daysInMonthGrid(for month: Date) -> [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstDay = monthInterval.start
        let dayRange = cal.range(of: .day, in: .month, for: month) ?? 1..<1

        let firstWeekday = cal.component(.weekday, from: firstDay)
        let leadingEmpty = (firstWeekday - cal.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingEmpty)

        for day in dayRange {
            var comps = cal.dateComponents([.year, .month], from: month)
            comps.day = day
            result.append(cal.date(from: comps))
        }

        while result.count % 7 != 0 {
            result.append(nil)
        }

        return result
    }
}

#Preview {
    @Previewable @State var displayedMonth = Date()
    @Previewable @State var startDate: Date? = Calendar.current.date(byAdding: .day, value: 2, to: Date())
    @Previewable @State var endDate: Date? = Calendar.current.date(byAdding: .day, value: 5, to: Date())
    @Previewable @State var isSelectingEnd = false

    return ScrollView {
        VStack(spacing: 20) {
            MonthCalendarView(
                displayedMonth: $displayedMonth,
                startDate: $startDate,
                endDate: $endDate,
                isSelectingEnd: $isSelectingEnd,
                minSelectableDate: Date()
            )

            CustomBackButton(action: {})

            OptionRow(title: "Friends", isSelected: true, onTap: {})

            PrimaryButton(title: "Continue", isEnabled: true, action: {})

            PrimaryButton(title: "Continue", isEnabled: false, action: {})
        }
        .padding()
    }
    .background(Color(hex: "F7FAF7"))
}
