import SwiftUI

/// The app's tab shell: Me (dashboard), Friends (social), Share (brag/export).
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = SummaryViewModel()
    @State private var friendsViewModel = FriendsViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: viewModel, friendsViewModel: friendsViewModel)
                .tabItem { Label("Me", systemImage: "figure.run") }
                .tag(0)

            FriendsTabView(viewModel: viewModel, friendsViewModel: friendsViewModel)
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(1)
                .badge(friendsViewModel.incoming.count + friendsViewModel.receivedReactions.count)

            ShareTabView(viewModel: viewModel, friendsViewModel: friendsViewModel)
                .tabItem { Label("Share", systemImage: "square.and.arrow.up") }
                .tag(2)
        }
        .tint(.cyan)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await friendsViewModel.refresh() }
            }
        }
        .onChange(of: SupabaseManager.shared.currentUserID) { _, _ in
            Task { await friendsViewModel.refresh() }
        }
        .task {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-periodYear") { viewModel.period = .year }
            if arguments.contains("-friendsTab") { selectedTab = 1 }
            if arguments.contains("-shareTab") { selectedTab = 2 }
            await viewModel.load()
            await friendsViewModel.refresh()
        }
    }
}

#Preview {
    RootView()
}
