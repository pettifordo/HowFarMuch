import SwiftUI

/// The app's tab shell: Me (dashboard), Friends (the social money shot),
/// and Share (brag card, text, CSV, invite). Settings lives at the top of
/// the Me tab. Global sharing sheets/alerts are hosted here so they work
/// whichever tab is showing.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = SummaryViewModel()
    @State private var friendsViewModel = FriendsViewModel()
    @State private var selectedTab = 0
    @State private var nameDraft = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: viewModel, friendsViewModel: friendsViewModel)
                .tabItem { Label("Me", systemImage: "figure.run") }
                .tag(0)

            FriendsTabView(viewModel: viewModel, friendsViewModel: friendsViewModel)
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(1)
                .badge(friendsViewModel.receivedReactions.isEmpty ? 0 : friendsViewModel.receivedReactions.count)

            ShareTabView(viewModel: viewModel, friendsViewModel: friendsViewModel)
                .tabItem { Label("Share", systemImage: "square.and.arrow.up") }
                .tag(2)
        }
        .tint(.cyan)
        .sheet(item: $friendsViewModel.sharePresentation) { presentation in
            CloudSharingView(
                share: presentation.share,
                container: presentation.container,
                onStopped: { Task { await friendsViewModel.refresh() } }
            )
            .ignoresSafeArea()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await friendsViewModel.refresh() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudShareAccepted)) { note in
            friendsViewModel.shareBackName = (note.object as? String) ?? "your friend"
            friendsViewModel.showShareBackPrompt = true
            selectedTab = 1
            Task { await friendsViewModel.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudShareAcceptFailed)) { note in
            friendsViewModel.statusMessage = note.object as? String
        }
        .alert("Following \(friendsViewModel.shareBackName)!", isPresented: $friendsViewModel.showShareBackPrompt) {
            Button("Share My Totals Back") {
                Task { await friendsViewModel.invite() }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("You can now see \(friendsViewModel.shareBackName)'s workout totals. They won't see yours until you send them your own invite link.")
        }
        .alert("What should friends call you?", isPresented: $friendsViewModel.showNamePrompt) {
            TextField("Your name", text: $nameDraft)
            Button("Save") {
                let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                AppSettings.displayName = trimmed
                Task { await friendsViewModel.nameSaved() }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("This is the name friends see next to your workout totals. You can change it any time in Settings → Sharing.")
        }
        .task {
            // Launch arguments below are only used by automated screenshot capture.
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-periodYear") {
                viewModel.period = .year
            }
            if arguments.contains("-friendsTab") {
                selectedTab = 1
            }
            if arguments.contains("-shareTab") {
                selectedTab = 2
            }
            await viewModel.load()
            await friendsViewModel.refresh()
        }
    }
}

#Preview {
    RootView()
}
