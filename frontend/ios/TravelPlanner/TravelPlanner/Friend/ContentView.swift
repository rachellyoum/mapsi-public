//
//  ContentView.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-01-29.
//

import SwiftUI
import FirebaseAuth

enum TopTab {
    case explore, schedule, community, profile
}
final class AppRouter: ObservableObject {
    
    @Published var topTab: TopTab = .explore
    @Published var path = NavigationPath()
}

struct ContentView: View {
    @State private var isLoggedIn: Bool = {
        let rememberMe = UserDefaults.standard.bool(forKey: "rememberMe")
        return rememberMe && Auth.auth().currentUser != nil
    }()
    @StateObject private var router = AppRouter()

    var body: some View {
        if isLoggedIn {
            Tabbar(isLoggedIn: $isLoggedIn)
                .environmentObject(router)
        } else {
            LoginView(isLoggedIn: $isLoggedIn)
        }
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
