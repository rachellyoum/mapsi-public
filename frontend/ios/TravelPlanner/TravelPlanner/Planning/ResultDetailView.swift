//
//  ResultDetailView.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-21.
//

import SwiftUI

struct ResultDetailView: View {
    let item: PlaceDetailItem
    @Environment(\.dismiss) private var dismiss

    private let deepGreen = Color(hex: "0B6B3A")
    private let softBackground = Color(hex: "F6F8F4")
    private let cardBackground = Color.white.opacity(0.72)
    private let cardStroke = Color.white.opacity(0.45)

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    heroImageSection(width: geometry.size.width)
                        .frame(width: geometry.size.width)
                        .clipped()

                    VStack(alignment: .leading, spacing: 18) {
                        headerSection
                        infoCard
                        activitySection

                        if let notes = item.notes, !notes.isEmpty {
                            notesSection(notes)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, -12)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 110)
                    .frame(width: geometry.size.width, alignment: .leading)
                    .clipped()
                }
                .frame(width: geometry.size.width, alignment: .leading)
                .clipped()
            }
        }
        .background(
            LinearGradient(
                colors: [
                    softBackground,
                    Color.white,
                    softBackground.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Place Detail")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(deepGreen)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func heroImageSection(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let photoURL = item.photo_url,
               !photoURL.isEmpty,
               let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderHero
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: 300)
                            .clipped()
                            .overlay(heroGradient)
                    case .failure:
                        placeholderHero
                    @unknown default:
                        placeholderHero
                    }
                }
            } else {
                placeholderHero
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(item.place_name)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)

                HStack(spacing: 10) {
                    if let rating = item.rating {
                        labelPill(systemName: "star.fill", text: String(format: "%.1f", rating), iconColor: .orange)
                    }

                    if detailPriceText != "Not available" {
                        labelPill(systemName: "banknote", text: detailPriceText, iconColor: deepGreen)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(width: width, height: 300)
        .clipped()
    }

    private var placeholderHero: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color(.tertiarySystemFill))
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .overlay(heroGradient)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
    }

    private var heroGradient: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.08),
                .black.opacity(0.18),
                .black.opacity(0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let address = item.address, !address.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(deepGreen.opacity(0.12))
                            .frame(width: 30, height: 30)

                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(deepGreen)
                    }

                    Text(address)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCard)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Information")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 14) {
                infoRow(title: "Category", value: displayCategory(from: item.type))
                dividerLine
                ratingInfoRow
                dividerLine
                infoRow(title: "Price Level", value: detailPriceText)
                dividerLine
                infoRow(title: "Opening Hours", value: openingHoursText)
                dividerLine
                infoRow(title: "Address", value: item.address ?? "Not available")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCard)
    }

    private var ratingInfoRow: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("Rating")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 105, alignment: .leading)

            if let rating = item.rating {
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: starName(for: rating, index: index))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                }
            } else {
                Text("Not available")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
    }

    private var openingHoursText: String {
        guard let openingHours = item.opening_hours,
              !openingHours.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Not available"
        }

        return openingHours
    }

    private var detailPriceText: String {
        if let stopPriceText = priceRangeText(item.stop_price_level), !stopPriceText.isEmpty {
            return stopPriceText
        }

        if let priceLevel = item.price_level {
            let text = priceText(for: priceLevel)
            return text.isEmpty ? "Not available" : text
        }

        return "Not available"
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            Text(item.activity)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCard)
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            Text(notes)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCard)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 105, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func labelPill(systemName: String, text: String, iconColor: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
    }

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    private func priceText(for level: Int) -> String {
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

    private func starName(for rating: Double, index: Int) -> String {
        let value = rating - Double(index)

        if value >= 1 {
            return "star.fill"
        } else if value >= 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

struct PlaceDetailItem: Identifiable, Hashable {
    let id = UUID()
    let place_name: String
    let type: String?
    let rating: Double?
    let activity: String
    let address: String?
    let price_level: Int?
    let stop_price_level: PriceLevelRange?
    let notes: String?
    let photo_url: String?
    let opening_hours: String?
}

//#Preview {
//    NavigationStack {
//        ResultDetailView(
//            item: PlaceDetailItem(
//                place_name: "Gyeongbokgung Palace",
//                type: "Historic Site",
//                rating: 4.7,
//                activity: "Explore the grand palace grounds, traditional architecture, and nearby cultural attractions.",
//                address: "161 Sajik-ro, Jongno District, Seoul, South Korea",
//                price_level: 1,
//                notes: "Visit early in the morning for fewer crowds and a calmer atmosphere.",
//                photo_url: nil
//            )
//        )
//    }
//}
