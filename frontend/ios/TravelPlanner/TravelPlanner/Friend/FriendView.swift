
import SwiftUI
 
struct FriendView: View {
    @StateObject private var vm = FriendViewModel()
    @ObservedObject var profileVM: ProfileViewModel
 
    @State private var showSearch      = false
    @State private var searchQuery     = ""
    @State private var selectedFriend: FriendUser?
    
    
 
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // ── Header ──────────────────────────────────────────────
                HStack(spacing: 16) {
                    Text("Friends")
                        .font(.system(size: 20, weight: .bold))
                    
                    Spacer()
                    
                    // Incoming requests bell with badge
                    Button { vm.showIncomingRequests = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                            
                            if !vm.incomingRequests.isEmpty {
                                Text("\(vm.incomingRequests.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                    
                    Button { withAnimation { showSearch.toggle() } } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                    
                    Button { vm.showAddFriend = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                // ── Search Bar ──────────────────────────────────────────
                if showSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                        
                        TextField("Search friends", text: $searchQuery)
                            .font(.system(size: 15))
                        
                        if !searchQuery.isEmpty {
                            Button { searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Divider()
                
                // ── My Profile Card ─────────────────────────────────────
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            AvatarPalette.colors[
                                (profileVM.user?.avatarColorIndex ?? 0) % AvatarPalette.colors.count
                            ]
                        )
                        .frame(width: 56, height: 56)
                       
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                        )
                        .clipShape(Circle())
                    
                    Text(profileVM.user?.name ?? "Me")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Divider()
                
                // ── Friend Count ────────────────────────────────────────
                HStack {
                    Text("Friends  \(vm.friendCount)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // ── List ────────────────────────────────────────────────
                if vm.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if vm.friends.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("No friends yet")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    let filtered = searchQuery.isEmpty
                    ? vm.friends
                    : vm.friends.filter { $0.displayName.localizedCaseInsensitiveContains(searchQuery) }
                    
                    List(filtered) { friend in
                        NavigationLink {
                            FriendProfileView(friend: friend, friendVM: vm)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(
                                        AvatarPalette.colors[
                                            (friend.avatarColorIndex ?? 0) % AvatarPalette.colors.count
                                        ]
                                    )
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                    )
                                    .clipShape(Circle())
                                
                                Text(friend.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                
                                Spacer()
                                
                                Button {
                                    selectedFriend = friend
                                   
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundColor(Color(.systemGray3))
                                        .font(.system(size: 16))
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(.systemBackground))
            .task {
                await vm.loadAll()
                profileVM.startListening()   // 🔥 이거 꼭 필요
            }
            .sheet(item: $selectedFriend) { friend in
                ManageSheet(
                    friend: friend,
                    vm: vm,
                    isPresented: .constant(true)
                )
            }
            .sheet(isPresented: $vm.showAddFriend) {
                AddFriendSheet(vm: vm)
            }
            .sheet(isPresented: $vm.showIncomingRequests) {
                IncomingRequestsSheet(vm: vm)
            }
            // Toast
            .overlay(alignment: .top) {
                if let msg = vm.errorMessage ?? vm.successMessage {
                    let isError = vm.errorMessage != nil
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isError ? Color.black.opacity(0.75) : Color(hex: "004428"))
                        .cornerRadius(20)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    vm.errorMessage   = nil
                                    vm.successMessage = nil
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.errorMessage)
            .animation(.easeInOut(duration: 0.2), value: vm.successMessage)
            .animation(.easeInOut(duration: 0.2), value: showSearch)
        }
    }
}
 
// MARK: - Manage Sheet
 
struct ManageSheet: View {
    let friend: FriendUser
    @ObservedObject var vm: FriendViewModel
    @Binding var isPresented: Bool
 
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)
 
            VStack(spacing: 8) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    )
                Text(friend.displayName)
                    .font(.system(size: 17, weight: .semibold))
                Text(friend.email)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 28)
 
            Divider()
 
            VStack(spacing: 0) {
                actionRow(icon: "person.fill.xmark", title: "Remove Friend", color: .primary) {
                    Task {
                        await vm.removeFriend(friend)
                        isPresented = false
                    }
                }
                Divider().padding(.leading, 52)
                actionRow(icon: "nosign", title: "Block", color: .red) {
                    Task {
                        await vm.block(friend)
                        isPresented = false
                    }
                }
            }
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 16)
 
            Spacer()
 
            Button { isPresented = false } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
 
    private func actionRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}
 
// MARK: - Incoming Requests Sheet
 
struct IncomingRequestsSheet: View {
    @ObservedObject var vm: FriendViewModel
 
    var body: some View {
        NavigationView {
            Group {
                if vm.incomingRequests.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("No pending requests")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(vm.incomingRequests) { request in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "person.fill").foregroundColor(.gray)
                                )
 
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.senderName ?? request.receiverName ?? "Unknown")
                                    .font(.system(size: 15, weight: .medium))
                                Text(request.senderEmail ?? request.receiverEmail ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
 
                            Spacer()
 
                            // Decline
                            Button {
                                Task { await vm.declineRequest(request) }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .frame(width: 34, height: 34)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
 
                            // Accept
                            Button {
                                Task { await vm.acceptRequest(request) }
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Color(hex: "004428"))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { vm.showIncomingRequests = false }
                }
            }
        }
    }
}
 
// MARK: - Add Friend Sheet
 
struct AddFriendSheet: View {
    @ObservedObject var vm: FriendViewModel
    @State private var query = ""
 
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
 
                // 🔍 검색바
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
 
                    TextField("Search by email", text: $query)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
 
                    if !query.isEmpty {
                        Button {
                            query = ""
                            vm.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
 
                // 🔄 로딩
                if vm.isSearchingUsers {
                    ProgressView()
                }
 
                // 🔥 결과 리스트
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
 
                        if !query.isEmpty {
                            Text("Search Results")
                                .font(.system(size: 15, weight: .bold))
                                .padding(.horizontal)
                        }
 
                        VStack(spacing: 12) {
                            ForEach(vm.searchResults) { user in
                                let email = user.email ?? ""
 
                                HStack(spacing: 12) {
 
                                    // 👤 프로필
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: "004428").opacity(0.12))
                                            .frame(width: 42, height: 42)
 
                                        Image(systemName: "person.fill")
                                            .foregroundColor(Color(hex: "004428"))
                                    }
 
                                    // 📝 텍스트
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.name ?? "Unknown")
                                            .font(.system(size: 15, weight: .semibold))
 
                                        Text(email)
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                    }
 
                                    Spacer()
 
                                    // 🔥 상태 버튼
                                    if vm.isAlreadyFriend(email) {
 
                                        Text("Added")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.gray)
 
                                    } else if vm.isPending(email) {
 
                                        Text("Pending")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.orange)
 
                                    } else {
 
                                        Button {
                                            Task {
                                                await vm.sendRequest(email: email)
                                                vm.showAddFriend = false
                                            }
                                        } label: {
                                            Text("Send")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Color(hex: "004428"))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(
                                                    Capsule()
                                                        .fill(Color(hex: "004428").opacity(0.12))
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
                        .padding(.horizontal)
                    }
                }
 
                Spacer()
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.showAddFriend = false
                    }
                }
            }
            .onChange(of: query) { _, newValue in
                vm.searchUsersDebounced(query: newValue)
            }
        }
    }
}
#Preview {
    NavigationStack {
        FriendView(profileVM: ProfileViewModel())
    }
}
