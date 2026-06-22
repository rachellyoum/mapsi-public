//
//  TravelPlannerApp.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-01-29.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct TravelPlannerApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
