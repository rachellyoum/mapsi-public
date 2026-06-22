import SwiftUI

struct ThemeSelectionView: View {
    @ObservedObject var vm: TripDraftViewModel
    @Binding var showPlanning: Bool
    @State private var goToBudget = false

    private let options = ["food", "cafes", "shopping", "museums", "nature", "nightlife", "culture", "family", "relax"]

    private var selectedThemes: [String] {
        vm.draft.preferences
            .filter { $0.hasPrefix("theme:") }
            .map { $0.replacingOccurrences(of: "theme:", with: "") }
    }

    var body: some View {
        ZStack {
            NavigationLink(
                destination: BudgetSelectionView(vm: vm, showPlanning: $showPlanning),
                isActive: $goToBudget
            ) {
                EmptyView()
            }
            .hidden()

            VStack(spacing: 0) {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("What is your theme?")
                            .font(.system(size: 16, weight: .semibold))

                        VStack(spacing: 12) {
                            ForEach(options, id: \.self) { option in
                                OptionRow(
                                    title: option.capitalized,
                                    isSelected: selectedThemes.contains(option)
                                ) {
                                    vm.toggleTheme(option)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                VStack {
                    PrimaryButton(
                        title: "NEXT",
                        isEnabled: !selectedThemes.isEmpty
                    ) {
                        goToBudget = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomBackButton {
                    showPlanning = false
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}
