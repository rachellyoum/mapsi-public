//
//  BannerView.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-02-28.
//

import SwiftUI

struct BannerView: View {
    private let deepGreen = Color(hex: "064229")
    private let midGreen = Color(hex: "0B6B3A")
    private let lightGreen = Color(hex: "35C48B")
    private let mint = Color(hex: "DDF3E6")
    var onTap: () -> Void = {}

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "0B6B3A").opacity(0.85),
                                Color(hex: "2FAF74").opacity(0.65),
                                Color(hex: "CFECDC")   // ← 아래 카드랑 맞추는 핵심
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 140, height: 140)
                        .offset(x: 120, y: -40)

                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 90, height: 90)
                        .offset(x: 70, y: 40)

                    cloudShape
                        .fill(Color.white.opacity(0.96))
                        .frame(width: 132, height: 54)
                        .offset(x: 84, y: 40)

                    Image("airplane")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 140)
                        .offset(x: 70, y: 10)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                HStack {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Find Flights")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Search and compare the best flight deals for your next trip.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)
                            .frame(maxWidth: 240, alignment: .leading)

                        Button {
                            onTap()
                        } label: {
                            Text("View Flights")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(deepGreen)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.94))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
            }
            .frame(height: 170)
            .shadow(color: midGreen.opacity(0.22), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var cloudShape: some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: 28,
            bottomLeadingRadius: 28,
            bottomTrailingRadius: 28,
            topTrailingRadius: 28
        )
    }
}

#Preview {
    ZStack {
        Color(hex: "F6F8F4").ignoresSafeArea()
        BannerView(onTap: {})
            .padding()
    }
}


