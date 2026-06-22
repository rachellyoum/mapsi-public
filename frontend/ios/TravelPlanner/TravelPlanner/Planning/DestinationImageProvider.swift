//
//  DestinationImageProvider.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-17.
//


import SwiftUI

enum DestinationImageProvider {
    static func imageName(for city: String, country: String? = nil) -> String {
        let normalizedCity = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCountry = country?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        if normalizedCity.contains("seoul") { return "SO" }
        if normalizedCity.contains("las vegas") { return "LV" }
        if normalizedCity.contains("tokyo") { return "TK" }
        if normalizedCity.contains("toronto") { return "TR" }
        if normalizedCity.contains("vancouver") { return "VC" }
        if normalizedCity.contains("new york") { return "NY" }
        if normalizedCity.contains("los angeles") || normalizedCity.contains("california") { return "LA" }
        if normalizedCity.contains("osaka") { return "OS" }
        if normalizedCity.contains("banff") { return "BF" }
        if normalizedCity.contains("cancun") { return "CN" }
        if normalizedCity.contains("mexico city") { return "MC" }
        if normalizedCity.contains("punta cana") { return "PC" }

        if normalizedCountry.contains("south korea") { return "SO" }
        if normalizedCountry.contains("japan") { return "TK" }
        if normalizedCountry.contains("canada") { return "VC" }
        if normalizedCountry.contains("usa") || normalizedCountry.contains("united states") { return "NY" }
        if normalizedCountry.contains("mexico") { return "CN" }

        return "default_destination"
    }
}
