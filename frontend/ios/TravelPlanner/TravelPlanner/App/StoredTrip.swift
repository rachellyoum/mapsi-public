//
//  StoredTrip.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-18.
//


import Foundation
import FirebaseFirestore

struct StoredTrip: Identifiable, Codable {
    @DocumentID var id: String?

    let userId: String
    let city: String
    let country: String
    let startDate: Date
    let endDate: Date
    let itinerary: GenerateTripResponse
    let createdAt: Date
}