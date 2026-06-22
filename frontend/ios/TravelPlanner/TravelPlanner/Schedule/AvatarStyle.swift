//
//  AvatarStyle.swift
//  TravelPlanner
//
//  Centralised pastel avatar colours used across Friend, Profile, and Schedule.
//

import SwiftUI

// MARK: - Palette

enum AvatarPalette {
    /// Ordered pastel swatches. Add or reorder here to update the whole app.
    static let colors: [Color] = [
        Color(hex: "FDAFAF"), // soft red / rose
               Color(hex: "FDDAAF"), // peach
               Color(hex: "FDF6AF"), // butter yellow
               Color(hex: "AFFDD8"), // mint
               Color(hex: "AFC8FD"), // periwinkle
               Color(hex: "D4AFFD"), // lavender
               Color(hex: "FDB8E8"), // blossom pink
    ]

    /// Foreground ink colour for text / icons drawn on top of an avatar.
    static let foreground = Color.black.opacity(0.55)

    /// Always returns the same colour for the same id (stable hash).
    static func color(for id: String) -> Color {
        let hash = abs(id.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Initials helper

enum AvatarInitials {
    /// Up to 2 initials from a display name, email, or raw id.
    static func letters(for displayName: String) -> String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

// MARK: - Reusable Avatar View

/// Drop-in circle avatar that shows initials in a pastel background.
/// Tapping shows a name tooltip for `tooltipDuration` seconds.
struct UserAvatarView: View { //fix
    /// The unique id used to pick a stable colour (user_id, uid, etc.)
    let userId: String
    /// Display name shown as initials and in the tooltip.
    let displayName: String
    let size: CGFloat
    
    let colorIndex: Int?
    
    /// How long the tooltip stays visible after a tap (seconds).
    var tooltipDuration: Double = 1.8
    /// Pass `false` to suppress the tooltip entirely (e.g. in dense lists).
    var showsTooltip: Bool = true

    @State private var tooltipVisible = false

    private var bg: Color {
        if let index = colorIndex {
            return AvatarPalette.colors[index % AvatarPalette.colors.count]
        }
        return AvatarPalette.color(for: userId) // fallback
    }
    private var initials: String { AvatarInitials.letters(for: displayName) }

    var body: some View {
        ZStack {
            Circle()
                .fill(bg)
                        .frame(width: size, height: size)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                        .shadow(color: .black.opacity(tooltipVisible ? 0.25 : 0.12), radius: 4)
                        .scaleEffect(tooltipVisible ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: tooltipVisible)


            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(AvatarPalette.foreground)
        }
        .overlay(alignment: .bottom) {
            if showsTooltip && tooltipVisible {
                tooltipBubble
                    .offset(y: size + 22)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                    .zIndex(99)
            }
        }
        .onTapGesture {
            guard showsTooltip else { return }
            withAnimation(.easeInOut(duration: 0.15)) { tooltipVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + tooltipDuration) {
                withAnimation(.easeInOut(duration: 0.2)) { tooltipVisible = false }
            }
        }
        .onLongPressGesture(minimumDuration: 0.25, pressing: { pressing in
            guard showsTooltip else { return }
            withAnimation(.easeInOut(duration: 0.15)) { tooltipVisible = pressing }
        }, perform: {})
    }

    private var tooltipBubble: some View {
        VStack(spacing: 2) {
            Text(displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black.opacity(0.72))
                )

            Image(systemName: "triangle.fill")
                .font(.system(size: 6))
                .foregroundStyle(Color.black.opacity(0.72))
                .rotationEffect(.degrees(180))
        }
        .fixedSize()
    }
}

// MARK: - Stacked Avatars Strip

/// Horizontal row of overlapping `UserAvatarView`s with an overflow badge.
struct AvatarStackView: View { //fix
    let members: [AvatarMember]
    var avatarSize: CGFloat = 30
    var maxVisible: Int = 4
    var showsTooltip: Bool = true

    /// 👇 겹치는 정도 (값 키우면 더 겹침)
    private let overlap: CGFloat = 10

    struct AvatarMember: Identifiable {
        let id: String
        let displayName: String
        let colorIndex: Int?   // ✅ 추가
    }
    var body: some View {
        let visible = Array(members.prefix(maxVisible))
        let overflow = max(0, members.count - maxVisible)

        HStack(spacing: -overlap) { // 🔥 핵심
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, member in
                UserAvatarView(
                    userId: member.id,
                    displayName: member.displayName,
                    size: avatarSize,
                    colorIndex: member.colorIndex   // ✅ 중요
                )
                .zIndex(Double(visible.count - index)) // 자연스러운 쌓임
            }

            if overflow > 0 {
                overflowBadge(count: overflow)
                    .zIndex(0)
            }
        }
        // ❌ frame 완전 삭제 (이게 핵심)
    }

    private func overflowBadge(count: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: avatarSize, height: avatarSize)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))

            Text("+\(count)")
                .font(.system(size: avatarSize * 0.30, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}



