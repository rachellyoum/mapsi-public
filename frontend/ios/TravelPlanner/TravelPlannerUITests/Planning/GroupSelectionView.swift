import SwiftUI

struct GroupSelectionView: View {
    @ObservedObject var vm: TripDraftViewModel
    @Binding var showPlanning: Bool
    @State private var goToTheme = false
    @Environment(\.dismiss) private var dismiss

    private let options = ["alone", "friends", "family", "couple", "kids"]

    private var selectedGroup: String? {
        vm.draft.preferences.first(where: { $0.hasPrefix("group:") })?
            .replacingOccurrences(of: "group:", with: "")
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Who are you going with?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    VStack(spacing: 12) {
                        ForEach(options, id: \.self) { option in
                            OptionRow(
                                title: option.capitalized,
                                isSelected: selectedGroup == option
                            ) {
                                vm.setPreference(key: "group", value: option)
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
                    isEnabled: selectedGroup != nil
                ) {
                    goToTheme = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .background(Color(.systemBackground))
        }
        .navigationTitle("Group")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomBackButton {
                    dismiss()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(isPresented: $goToTheme) {
            ThemeSelectionView(vm: vm, showPlanning: $showPlanning)
        }
    }
}

#Preview {
    NavigationStack {
        GroupSelectionView(
            vm: TripDraftViewModel(userId: "preview-user"),
            showPlanning: .constant(true)
        )
    }
}
