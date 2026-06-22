//
//  SavedScheduleCardView.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-18.
//


import SwiftUI

struct SavedScheduleCardView: View {
    let trip: SavedScheduleMock
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "DCEFE4"),
                            Color(hex: "D8F5E7"),
                            Color(hex: "C6E7D5")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1.2)
                }
                .shadow(color: Color(hex: "0B6B3A").opacity(0.12), radius: 20, x: 0, y: 10)
            
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "103522"))
                    
                    Text(trip.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
                
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: trip.imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .overlay(ProgressView())
                        }
                    }
                    .frame(height: 205)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    
                    HStack {
                        pillText(trip.dateText)
                        Spacer()
                        pillText("★ \(trip.rating)")
                    }
                    .padding(14)
                }
            }
            .padding(18)
            
            VStack {
                HStack {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 170, height: 36)
                    .blur(radius: 2)
                    .clipShape(Capsule())
                    
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 12)
            .padding(.leading, 16)
        }
    }
    
    private func pillText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color(hex: "064229"))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.82))
            .clipShape(Capsule())
    }
}