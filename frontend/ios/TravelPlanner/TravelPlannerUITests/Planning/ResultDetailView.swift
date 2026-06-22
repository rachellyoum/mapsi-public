//
//  ResultDetailView.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-21.
//

import SwiftUI

struct ResultDetailView: View {
    let item: PlaceDetailItem

    private let deepGreen = Color(hex: "0B6B3A")
    private let softBackground = Color(hex: "F6F8F4")
    private let cardBackground = Color.white.opacity(0.72)
    private let cardStroke = Color.white.opacity(0.45)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                heroImageSection

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
                .padding(.bottom, 32)
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
    }

    private var heroImageSection: some View {
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
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
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

                    if let priceLevel = item.price_level {
                        labelPill(systemName: "banknote", text: priceText(for: priceLevel), iconColor: deepGreen)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(height: 300)
    }

    private var placeholderHero: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color(.tertiarySystemFill))
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
            Text(item.place_name)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

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
                infoRow(title: "Category", value: item.type ?? "Not available")
                dividerLine
                infoRow(title: "Rating", value: item.rating.map { String(format: "%.1f", $0) } ?? "Not available")
                dividerLine
                infoRow(title: "Price Level", value: item.price_level.map(priceText(for:)) ?? "Not available")
                dividerLine
                infoRow(title: "Address", value: item.address ?? "Not available")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glassCard)
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
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .medium))
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
        guard level > 0 else { return "Free" }
        return String(repeating: "$", count: level)
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
    let notes: String?
    let photo_url: String?
}

#Preview {
    NavigationStack {
        ResultDetailView(
            item: PlaceDetailItem(
                place_name: "Gyeongbokgung Palace",
                type: "Historic Site",
                rating: 4.7,
                activity: "Explore the grand palace grounds, traditional architecture, and nearby cultural attractions.",
                address: "161 Sajik-ro, Jongno District, Seoul, South Korea",
                price_level: 1,
                notes: "Visit early in the morning for fewer crowds and a calmer atmosphere.",
                photo_url: nil
            )
        )
    }
}
