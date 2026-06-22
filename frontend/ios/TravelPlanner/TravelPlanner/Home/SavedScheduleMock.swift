//
//  SavedScheduleMock.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-18.
//


import Foundation

struct SavedScheduleMock: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let imageURL: String
    let dateText: String
    let rating: String
}