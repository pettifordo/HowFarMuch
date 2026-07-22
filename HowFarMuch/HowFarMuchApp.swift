import SwiftUI

@main
struct HowFarMuchApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .task { await SupabaseManager.shared.start() }
        }
    }
}
