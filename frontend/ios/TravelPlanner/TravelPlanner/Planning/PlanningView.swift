//
//  PlanningView.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-02-28.
//

import SwiftUI
import FirebaseAuth

struct PlanningView: View {
    @Binding var showPlanning: Bool
    @StateObject private var vm: TripDraftViewModel

    init(showPlanning: Binding<Bool>) {
        self._showPlanning = showPlanning
        let uid = Auth.auth().currentUser?.uid ?? "test-user-id"
        _vm = StateObject(wrappedValue: TripDraftViewModel(userId: uid))
    }

    var body: some View {
        NavigationStack {
            DestinationPickerView(
                vm: vm,
                userId: Auth.auth().currentUser?.uid ?? "test-user-id",
                showPlanning: $showPlanning
            )
        }
        .onAppear {
            vm.resetDraft()
        }
        
    }
}
#Preview {
    PlanningView(showPlanning: .constant(true))
        .environmentObject(AppRouter())
}

