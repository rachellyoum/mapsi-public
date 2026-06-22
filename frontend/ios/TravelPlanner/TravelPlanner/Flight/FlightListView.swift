//
//  FlightListView.swift
//  TravelPlanner
//
//  Created by Kylie Kim on 2026-03-11.
//
 
import SwiftUI
 
struct FlightListView: View {
    @ObservedObject var viewModel: FlightViewModel
    @Environment(\.dismiss) private var dismiss
 
    var body: some View {
        // ✅ ZStack으로 전체 감싸서 navigationBar 여백 완전 제거
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.96).ignoresSafeArea()
 
            VStack(spacing: 0) {
                headerSection
                resultsBanner
                flightListContent
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        // ✅ 핵심: ignoresSafeArea로 상단 빈 공간 제거
        .ignoresSafeArea(edges: .top)
    }
 
    // MARK: - Header
 
    private var headerSection: some View {
        HStack {
            Button {
                viewModel.showResults = false
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }
            Spacer()
            Text("MAPSI")
                .font(.custom("DynaPuff-Medium", size: 32))
                .foregroundColor(Color(hex: "064229"))
            Spacer()
            Color.clear.frame(width: 20)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        // ✅ safeArea 위에 패딩 수동으로
        .padding(.top, safeAreaTop() + 10)
        .background(Color.white)
    }
 
    // MARK: - Banner
 
    private var resultsBanner: some View {
        ZStack(alignment: .bottom) {
            Color.mapsiGreen
 
            VStack(spacing: 0) {
                Text("Search result")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.top, 16)
                    .padding(.bottom, 10)
 
                // ✅ FROM - 아치 - TO
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
 
                    ZStack {
                        // 아치 점선 (위로 볼록 ∩)
                        ArcShape()
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 56)
 
                        // 비행기 — 아치 꼭대기
                        Image(systemName: "airplane")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .position(x: w / 2, y: h * 0.12)
 
                        // FROM 코드
                        Text(viewModel.effectiveFrom.uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .position(x: 46, y: h * 0.82)
 
                        // TO 코드
                        Text(viewModel.effectiveTo.uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .position(x: w - 46, y: h * 0.82)
                    }
                }
                .frame(height: 90)
                .padding(.horizontal, 20)
 
                // 항공편 수
                Group {
                    if viewModel.isLoading {
                        Text("Searching...")
                    } else {
                        Text("\(viewModel.flights.count) flights available")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
 
            // 하단 웨이브
            BottomWaveShape()
                .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
                .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
    }
 
    // MARK: - List Content
 
    @ViewBuilder
    private var flightListContent: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView("Loading flights...").tint(.mapsiGreen)
            Spacer()
 
        } else if let error = viewModel.errorMessage {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40)).foregroundColor(.orange)
                Text(error)
                    .font(.system(size: 14)).foregroundColor(.gray)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                Button("Try Again") { viewModel.searchFlights() }
                    .foregroundColor(.mapsiGreen)
                    .font(.system(size: 15, weight: .semibold))
            }
            Spacer()
 
        } else if viewModel.flights.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "airplane.circle")
                    .font(.system(size: 48)).foregroundColor(.mapsiGreen.opacity(0.5))
                Text("No flights found")
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.gray)
            }
            Spacer()
 
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.flights) { flight in
                        FlightTicketCard(flight: flight)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
    }
}
 
// MARK: - Safe Area Helper
 
private func safeAreaTop() -> CGFloat {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first else { return 44 }
    return window.safeAreaInsets.top
}
 
// MARK: - Arc Shape ∩
 
struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}
 
// MARK: - Bottom Wave
 
struct BottomWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY - 8)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
 
// MARK: - Flight Ticket Card
 
struct FlightTicketCard: View {
    let flight: Flight
 
    private var airlineColor: Color {
        switch flight.airline.name.lowercased() {
        case let s where s.contains("air canada"):  return Color(red: 0.85, green: 0.10, blue: 0.15)
        case let s where s.contains("westjet"):     return Color(red: 0.0,  green: 0.47, blue: 0.84)
        case let s where s.contains("delta"):       return Color(red: 0.70, green: 0.05, blue: 0.15)
        case let s where s.contains("united"):      return Color(red: 0.0,  green: 0.20, blue: 0.56)
        case let s where s.contains("american"):    return Color(red: 0.0,  green: 0.37, blue: 0.63)
        case let s where s.contains("southwest"):   return Color(red: 0.87, green: 0.60, blue: 0.0)
        case let s where s.contains("jetblue"):     return Color(red: 0.0,  green: 0.45, blue: 0.70)
        case let s where s.contains("alaska"):      return Color(red: 0.0,  green: 0.27, blue: 0.53)
        default:                                    return Color.mapsiGreen
        }
    }
 
    var body: some View {
        VStack(spacing: 0) {
 
            // ── Airline Header ──
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "airplane")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                    )
                Text(flight.airline.name.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(0.5)
                Spacer()
                Text(flight.priceFormatted)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(airlineColor)
            .clipShape(RoundedCornerTop(radius: 14))
 
            // ── Tear Line ──
            TicketTearLine()
 
            // ── Flight Info ──
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Depart")
                        .font(.system(size: 10)).foregroundColor(.mapsiTextGray)
                    Text(flight.departureTime)
                        .font(.system(size: 22, weight: .bold)).foregroundColor(.black)
                    Text(flight.departureCode)
                        .font(.system(size: 11)).foregroundColor(.mapsiTextGray)
                }
 
                Spacer()
 
                VStack(spacing: 4) {
                    Text(flight.duration)
                        .font(.system(size: 10)).foregroundColor(.mapsiTextGray)
                    HStack(spacing: 0) {
                        Circle()
                            .stroke(Color.mapsiGreen, lineWidth: 1.5)
                            .frame(width: 7, height: 7)
                        TicketDashedLine()
                            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3]))
                            .foregroundColor(.mapsiGreen.opacity(0.5))
                            .frame(width: 28, height: 1)
                        Image(systemName: "airplane")
                            .font(.system(size: 11)).foregroundColor(.mapsiGreen)
                        TicketDashedLine()
                            .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [3]))
                            .foregroundColor(.mapsiGreen.opacity(0.5))
                            .frame(width: 28, height: 1)
                        Circle()
                            .fill(Color.mapsiGreen)
                            .frame(width: 7, height: 7)
                    }
                    Text(flight.stopsText)
                        .font(.system(size: 10))
                        .foregroundColor(flight.stops == 0 ? .mapsiGreen : .orange)
                }
 
                Spacer()
 
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Arrive")
                        .font(.system(size: 10)).foregroundColor(.mapsiTextGray)
                    Text(flight.arrivalTime)
                        .font(.system(size: 22, weight: .bold)).foregroundColor(.black)
                    Text(flight.arrivalCode)
                        .font(.system(size: 11)).foregroundColor(.mapsiTextGray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
 
            // ── Barcode ──
            HStack {
                Spacer()
                TicketBarcodeView()
                    .frame(width: 80, height: 28)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
            }
            .background(Color.white)
            .clipShape(RoundedCornerBottom(radius: 14))
        }
        .shadow(color: Color.black.opacity(0.09), radius: 10, x: 0, y: 4)
    }
}
 
// MARK: - Tear Line
 
struct TicketTearLine: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.white
                Circle()
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
                    .frame(width: 22, height: 22)
                    .position(x: -2, y: 10)
                Circle()
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
                    .frame(width: 22, height: 22)
                    .position(x: geo.size.width + 2, y: 10)
                TicketDashedLine()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundColor(Color.gray.opacity(0.25))
                    .frame(height: 1)
                    .padding(.horizontal, 14)
                    .position(x: geo.size.width / 2, y: 10)
            }
        }
        .frame(height: 20)
        .clipped()
    }
}
 
// MARK: - Barcode
 
struct TicketBarcodeView: View {
    private let bars: [CGFloat] = [2,4,2,1,3,1,2,4,1,2,3,1,2,1,4,2,1,3,2,1]
    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(0..<bars.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.black.opacity(0.75))
                    .frame(width: bars[i], height: i % 3 == 0 ? 28 : 20)
            }
        }
    }
}
 
// MARK: - Shapes
 
struct TicketDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
 
struct RoundedCornerTop: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                          control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
 
struct RoundedCornerBottom: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.maxY),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
 
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
