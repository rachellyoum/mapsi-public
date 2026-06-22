import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = ProfileViewModel()
    
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var showManageAccount = false
    
    @State private var showColorPicker = false
    
    
    private let deepGreen = Color(hex: "064229")
    private let midGreen = Color(hex: "0B6B3A")
    private let lightGreen = Color(hex: "22C07A")
    private let softMint = Color(hex: "EAF7EF")
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            Button {
                                showColorPicker = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            AvatarPalette.colors[
                                                (vm.user?.avatarColorIndex ?? 0) % AvatarPalette.colors.count
                                            ]
                                        )
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "person.fill")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vm.user?.name ?? "User")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                                
                                Text(vm.user?.email ?? "")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer(minLength: 8)
                            
                            Button {
                                showLogoutAlert = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Sign out")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(deepGreen)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.9))
                                )
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white,
                                            Color(hex: "F3FBF6")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(deepGreen.opacity(0.08), lineWidth: 1)
                        }
                    )
                    .shadow(color: deepGreen.opacity(0.05), radius: 14, x: 0, y: 8)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                
                    
                    
                    VStack(spacing: 0) {
                        menuRow(icon: "bell.fill", title: "Notification") {
                            let current = vm.user?.notificationsEnabled ?? true
                            vm.toggleNotifications(!current)
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        menuRow(icon: "gearshape.fill", title: "Manage Account") {
                            showManageAccount = true
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        menuRow(icon: "bookmark.fill", title: "Saved Trips") {
                            vm.savedTripsTapped()
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        menuRow(icon: "questionmark.circle.fill", title: "Help & Support") {
                            vm.helpTapped()
                        }
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        menuRow(icon: "trash.fill", title: "Delete Account", isDestructive: true) {
                            showDeleteAlert = true
                        }
                    }
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.92))
                            
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color(hex: "E5EEE8"), lineWidth: 1)
                        }
                    )
                    .shadow(color: deepGreen.opacity(0.05), radius: 14, x: 0, y: 8)
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .background(Color(hex: "F7FAF7"))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { //fix
                vm.startListening()
                vm.ensureAvatarColorExists()
            }
            .onDisappear {
                vm.stopListening()
            }
            .sheet(isPresented: $showManageAccount) {
                manageAccountView
            }
            .sheet(isPresented: $showColorPicker) {
                VStack(spacing: 24) {

                    Text("Choose Avatar Color")
                        .font(.headline)

                    HStack(spacing: 14) {
                        ForEach(Array(AvatarPalette.colors.enumerated()), id: \.offset) { index, color in

                            ZStack {
                                Circle()
                                    .fill(color)
                                    .frame(width: 40, height: 40)

                                if vm.user?.avatarColorIndex == index {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.white)
                                }
                            }
                            .onTapGesture {
                                vm.updateAvatarColor(index)
                                showColorPicker = false
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
                .presentationDetents([.height(180)])
            }
            
            .alert("Sign Out?", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    vm.signOut { success in
                        if success {
                            isLoggedIn = false
                        }
                    }
                }
            }
            .alert("Delete Account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    vm.deleteAccount { success in
                        if success {
                            isLoggedIn = false
                        }
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
    
    // MARK: MENU ROW
    
    private func menuRow(
        icon: String,
        title: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            isDestructive
                            ? Color.red.opacity(0.12)
                            : softMint
                        )
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            isDestructive
                            ? AnyShapeStyle(Color.red.opacity(0.9))
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [midGreen, lightGreen],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        isDestructive
                        ? Color.red.opacity(0.92)
                        : Color.primary.opacity(0.9)
                    )
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.7))
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
    }
    
    // MARK: MANAGE ACCOUNT VIEW
    
    private var manageAccountView: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer().frame(height: 20)
                
                Text("MAPSI")
                    .font(.custom("DynaPuff-Medium", size: 40))
                    .padding(.bottom, 20)
                    .foregroundColor(Color(hex: "064229"))
                
                VStack(spacing: 0) {
                    NavigationLink {
                        changeNameView
                    } label: {
                        accountRow(title: "Change Name")
                    }
                    
                    Divider()
                    
                    NavigationLink {
                        changePasswordView
                    } label: {
                        accountRow(title: "Change Password")
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .padding(.horizontal)
                
                Spacer()
            }
            .background(Color(hex: "F7FAF7"))
        }
    }
    
    private var changeNameView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            
            Text("Change Name")
                .font(.title2)
                .fontWeight(.semibold)
            
            TextField("Full Name", text: $vm.tempName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            Button {
                vm.updateNameOnly()
            } label: {
                Text("Save")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "064229"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
        }
        .background(Color(hex: "F7FAF7"))
        .alert(vm.successMessage, isPresented: $vm.showSuccessMessage) {
            Button("OK") {
                showManageAccount = false
            }
        }
    }
    
    private var changePasswordView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            
            Text("Change Password")
                .font(.title2)
                .fontWeight(.semibold)
            
            SecureField("New Password", text: $vm.tempPassword)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            SecureField("Confirm Password", text: $vm.tempConfirmPassword)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            Button {
                vm.updatePasswordOnly()
            } label: {
                Text("Save")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "064229"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Spacer()
        }
        .background(Color(hex: "F7FAF7"))
        .alert(vm.successMessage, isPresented: $vm.showSuccessMessage) {
            Button("OK") {
                showManageAccount = false
            }
        }
    }
    
    private func accountRow(title: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.black)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
    }

}

#Preview {
    ProfileView(isLoggedIn: .constant(true))
}
