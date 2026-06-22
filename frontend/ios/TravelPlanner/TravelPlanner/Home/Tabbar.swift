import SwiftUI

struct Tabbar: View {
    @EnvironmentObject private var router: AppRouter
    @Binding var isLoggedIn: Bool
    @State private var showPlanning = false
    @State private var isChildScreenHidingTabBar = false
    @StateObject private var profileVM = ProfileViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch router.topTab {
                case .explore:
                    HomeView()
                case .community:
                    FriendView(profileVM: profileVM)
                case .schedule:
                    ScheduleView()
                case .profile:
                    ProfileView(isLoggedIn: $isLoggedIn)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !showPlanning && !isChildScreenHidingTabBar {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 1)
                    
                    HStack(alignment: .center, spacing: 0) {
                        tabIcon(
                            system: router.topTab == .explore ? "house.fill" : "house",
                            title: "Home",
                            tab: .explore
                        )
                        
                        tabIcon(
                            system: router.topTab == .community ? "person.2.fill" : "person.2",
                            title: "Friends",
                            tab: .community
                        )
                        
                        Button {
                            showPlanning = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "0B6B3A"),
                                                Color(hex: "22C07A")
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 46, height: 46)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                    )
                                    .shadow(color: Color(hex: "0B6B3A").opacity(0.16), radius: 4, y: 2)
                                
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                    .font(.system(size: 22, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        tabIcon(
                            system: router.topTab == .schedule ? "bookmark.fill" : "bookmark",
                            title: "Archive",
                            tab: .schedule
                        )
                        
                        tabIcon(
                            system: router.topTab == .profile ? "gearshape.fill" : "gearshape",
                            title: "Settings",
                            tab: .profile
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 1)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
                .background(
                    ZStack {
                        BlurView(style: .systemUltraThinMaterial)

                        Color.white.opacity(0.78)

                        LinearGradient(
                            colors: [
                                Color(hex: "E6F2EB").opacity(0.92),
                                Color.white.opacity(0.64)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.65))
                        .frame(height: 1)
                }
            }
        }
        .fullScreenCover(isPresented: $showPlanning) {
            PlanningView(showPlanning: $showPlanning)
                .environmentObject(router)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HideCustomTabBar"))) { _ in
            isChildScreenHidingTabBar = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowCustomTabBar"))) { _ in
            showPlanning = false
            isChildScreenHidingTabBar = false
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClosePlanning"))) { _ in
            showPlanning = false
            isChildScreenHidingTabBar = false
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToScheduleTab"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                router.topTab = .schedule
            }
        }
    }
    
    private func tabIcon(system: String, title: String, tab: TopTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                router.topTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: system)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(
                        router.topTab == tab
                        ? Color(hex: "004428")
                        : Color.gray.opacity(0.78)
                    )
                    .scaleEffect(router.topTab == tab ? 1.08 : 1.0)
                
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(
                        router.topTab == tab
                        ? Color(hex: "004428")
                        : Color.gray.opacity(0.9)
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct CommunityView: View {
    var body: some View {
        Text("Community").padding()
    }
}

#Preview {
    Tabbar(isLoggedIn: .constant(true))
        .environmentObject(AppRouter())
}
