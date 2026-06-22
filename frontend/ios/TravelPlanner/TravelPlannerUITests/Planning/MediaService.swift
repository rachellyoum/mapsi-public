//
//  MediaService.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-18.
//


import Foundation

struct CityPhotoResponse: Decodable {
    let photo_url: String?
}

struct MediaService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetchCityPhotoURL(city: String) async throws -> String? {
        let response: CityPhotoResponse = try await client.get(
            "media/city-photo",
            queryItems: [
                URLQueryItem(name: "city", value: city.lowercased())
            ]
        )

        guard let raw = response.photo_url, !raw.isEmpty else {
            return nil
        }

        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return raw
        }

        let trimmed = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
        let absolute = client.baseURL.appendingPathComponent(trimmed).absoluteString
        return absolute
    }
}
