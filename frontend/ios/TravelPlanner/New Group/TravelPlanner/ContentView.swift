//
//  ContentView.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-01-29.
//

import SwiftUI

/*struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
*/


struct ContentView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea() // 배경색
            
            VStack(spacing: 0) {
                // 상단 헤더
                HStack {
                    Text("MAPSI")
                        .font(.system(size: 28, weight: .black))
                    Spacer()
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                }
                .padding()

                // 탭 메뉴 (Explore 등)
                HStack(spacing: 25) {
                    VStack(spacing: 4) {
                        Text("Explore").bold()
                        Rectangle().frame(height: 2).foregroundColor(Color(hex: "064229"))
                    }
                    Text("My schedule").foregroundColor(.gray)
                    Text("Community").foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 티켓 섹션 (GENERATE MY TRIP)
                        TicketView()
                            .padding(.top)

                        // 스위스 홍보 배너 (디자인 이미지 영역)
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 180)
                            .overlay(Text("SWITZERLAND").font(.largeTitle).bold().foregroundColor(.white))
                            .padding(.horizontal)

                        // 국가별 아이콘 리스트
                        Text("Popular Destinations").font(.headline).padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                DestinationCircle(name: "KOREA", flag: "🇰🇷")
                                DestinationCircle(name: "USA", flag: "🇺🇸")
                                DestinationCircle(name: "CANADA", flag: "🇨🇦")
                                DestinationCircle(name: "BRAZIL", flag: "🇧🇷")
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }
}

// 티켓 디자인 컴포넌트
struct TicketView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("GENERATE MY TRIP")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding()
            .background(Color(hex: "064229")) // 디자인의 딥 그린
            
            HStack {
                VStack { Text("FROM").font(.caption); Text("HERE").bold() }
                Spacer()
                Image(systemName: "airplane")
                Spacer()
                VStack { Text("TO").font(.caption); Text("ANYWHERE").bold() }
            }
            .padding()
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
}

// 국가 원형 컴포넌트
struct DestinationCircle: View {
    var name: String
    var flag: String
    var body: some View {
        VStack {
            Circle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 70, height: 70)
                .overlay(Text(flag).font(.system(size: 35)))
            Text(name).font(.caption).bold()
        }
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#") // #이 붙어있어도 처리 가능하게
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xff0000) >> 16) / 255.0
        let g = Double((rgbValue & 0xff00) >> 8) / 255.0
        let b = Double(rgbValue & 0xff) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
