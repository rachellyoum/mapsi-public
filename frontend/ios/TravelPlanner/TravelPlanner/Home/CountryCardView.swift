//
//  CountryCircleCard.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-02-28.
//

import SwiftUI

struct CountryCardView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    struct CountryItem: Identifiable{
        let id = UUID()
        let countryName: String
        let code: String
    }
    
    private let countries: [CountryItem] = [
        .init(countryName: "Canada", code: "CA"),
        .init(countryName: "USA", code: "US"),
        .init(countryName: "KOREA", code: "KR"),
        .init(countryName: "JAPAN", code: "JP"),
        .init(countryName: "Maxico", code: "MX")
    ]
    
    struct CityItem: Identifiable{
        let id = UUID()
        let cityName : String
        let countryOfCity: String
        let citycode: String
    }
    
    private let cities: [CityItem] = [
        .init(cityName: "Las Vegas", countryOfCity: "USA", citycode: "LV"),
        .init(cityName: "Tokyo" , countryOfCity: "JAPAN", citycode: "TK"),
        .init(cityName: "Seoul" , countryOfCity: "KOREA" , citycode: "SO")
    ]
    
    var body: some View{
//        ScrollView(.horizontal, showsIndicators: false){
//            HStack {
//                ForEach(countries) { country in
//                    NavigationLink{
//                        CountryDetailView(country:country)
//                    }label:{
//                        CountryCard(country:country)
//                            .contentShape(.circle)
//                            . padding(.horizontal, 12)
//                    }
//                    .buttonStyle(.plain)
//                }
//            }
//            .padding(.horizontal, 10)
//        }
//        .padding(.bottom, 10)
        
        ScrollView(.horizontal, showsIndicators: false){
            HStack{
                Spacer(minLength: 20)
                ForEach(cities) { city in
                    NavigationLink{
                        CityDetailView(city:city)
                    }label:{
                        CityCard(city:city)
                            .contentShape(Rectangle())
//                            .padding(.horizontal, 1)
                    }
                    
                }
            }
        }
    }
    
}
private struct CountryCard: View{
    let country: CountryCardView.CountryItem
    
    var body: some View{
        VStack{
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(flag(from: country.code))
                        .font(.system(size: 40))
                    )
                
            VStack{
                Text(country.countryName)
                    .font(.subheadline)
            }
        }
    }
}


private struct CityCard: View {
    let city: CountryCardView.CityItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            Image(city.citycode)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150) // 정사각형
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)


            VStack(alignment: .leading, spacing: 2) {
                Text(city.countryOfCity.uppercased())   
                    .font(.caption2)
                    .foregroundColor(.gray)

                Text(city.cityName)
                    .font(.caption)
                    .foregroundColor(.black)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2) // 살짝만 정렬용
        }
        .frame(width: 170, alignment: .leading) // 전체 폭 고정 (가로 스크롤용)
    }
}

private struct CountryDetailView: View{
    let country: CountryCardView.CountryItem
    
    var body: some View{
        VStack{
            Text(country.countryName)
                .font(.largeTitle)
            Text("Description")
                .font(.subheadline)
            Divider()
            Spacer()
        }
    }

}

private struct CityDetailView: View {
    let city: CountryCardView.CityItem

    var body: some View {
        VStack{
            Text(city.cityName)
                .font(.largeTitle)
                .foregroundStyle(.black)
            Text(city.countryOfCity)
                .font(.subheadline)
                .foregroundStyle(.gray)

            Divider()
            Spacer()
        }
    }
}


func flag(from countryCode: String) -> String {
    countryCode
        .uppercased()
        .unicodeScalars
        .map { 127397 + $0.value }
        .compactMap { UnicodeScalar($0) }
        .map { String($0) }
        .joined()
}

#Preview {
    NavigationStack {
            CountryCardView()
    }
}
