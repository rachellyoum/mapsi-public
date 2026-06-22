//
//  ShareTripView.swift
//  TravelPlanner
//
//  Created by Yein Hwang on 2026-03-18.
//


import SwiftUI

struct ShareTripView: View {
    let tripId: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ShareTripViewModel()
    @State private var selectedRole: String = "viewer"

    private let deepGreen = Color(hex: "0B6B3A")

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Search by name", text: $viewModel.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if !viewModel.query.isEmpty {
                            Button {
                                viewModel.query = ""
                                viewModel.users = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                    )

                    Picker("Role", selection: $selectedRole) {
                        Text("Viewer").tag("viewer")
                        Text("Editor").tag("editor")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if viewModel.isLoading && viewModel.users.isEmpty && viewModel.members.isEmpty {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                searchSection
                            }

                            membersSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Share Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadMembers(tripId: tripId)
            }
            .onChange(of: viewModel.query) { _, newValue in
                Task {
                    await viewModel.searchUsers(query: newValue)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Done", isPresented: Binding(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.successMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Results")
                .font(.system(size: 20, weight: .bold))

            if viewModel.users.isEmpty && !viewModel.isLoading {
                Text("No users found.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.users) { user in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(deepGreen.opacity(0.12))
                                .frame(width: 42, height: 42)

                            Image(systemName: "person.fill")
                                .foregroundStyle(deepGreen)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.name ?? "Unknown User")
                                .font(.system(size: 15, weight: .semibold))

                            if let email = user.email, !email.isEmpty {
                                Text(email)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            Task {
                                await viewModel.shareTrip(
                                    tripId: tripId,
                                    targetUserId: user.id,
                                    role: selectedRole
                                )
                            }
                        } label: {
                            if viewModel.isSharing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Share")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(deepGreen)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(deepGreen.opacity(0.12))
                                    )
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared With")
                .font(.system(size: 20, weight: .bold))

            if viewModel.members.isEmpty && !viewModel.isLoading {
                Text("This trip is not shared yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.members) { member in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.10))
                                .frame(width: 40, height: 40)

                            Image(systemName: "person.2.fill")
                                .foregroundStyle(.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name ?? member.email ?? member.user_id)
                                .font(.system(size: 14, weight: .semibold))

                            Text(member.role.capitalized)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
    }
}