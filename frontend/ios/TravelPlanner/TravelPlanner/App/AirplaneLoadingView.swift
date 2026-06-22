//
//  AirplaneLoadingView.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-04-21.
//


import SwiftUI

struct AirplaneLoadingView: View {
    @State private var rotate = false
    private let deepGreen = Color(hex: "064229")
    private let midGreen = Color(hex: "0B6B3A")
    private let mintGreen = Color(hex: "E7F4EC")

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    mintGreen,
                    Color.white,
                    Color(hex: "DDF3E6")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Soft background circles
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 260, height: 260)
                .blur(radius: 8)

            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: 180, height: 180)

            // Dashed loading orbit
            Circle()
                .trim(from: 0.08, to: 0.92)
                .stroke(
                    midGreen.opacity(0.25),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [8, 10])
                )
                .frame(width: 180, height: 180)

            // Rotating airplane
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 180, height: 180)

                Image(systemName: "airplane")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(midGreen)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.95))
                            .shadow(color: midGreen.opacity(0.25), radius: 10, x: 0, y: 4)
                    )
                    .offset(y: -90) // radius
                    .rotationEffect(.degrees(45)) // airplane nose points along path
            }
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .animation(
                .linear(duration: 2.2).repeatForever(autoreverses: false),
                value: rotate
            )

            VStack(spacing: 220) {
                Text("Loading...")
                    .font(.headline)
                    .foregroundStyle(midGreen.opacity(0.8))
                    .tracking(0.5)
            }
        }
        .onAppear {
            rotate = true
        }
    }
}

#Preview {
    AirplaneLoadingView()
}
