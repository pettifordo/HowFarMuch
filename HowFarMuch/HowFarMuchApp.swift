import SwiftUI
import CloudKit
import UIKit

@main
struct HowFarMuchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - CloudKit share acceptance (friend invites)

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

extension Notification.Name {
    static let cloudShareAccepted = Notification.Name("cloudShareAccepted")
    static let cloudShareAcceptFailed = Notification.Name("cloudShareAcceptFailed")
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task {
            do {
                try await FriendsService().acceptShare(metadata: cloudKitShareMetadata)
                NotificationCenter.default.post(name: .cloudShareAccepted, object: nil)
            } catch {
                NotificationCenter.default.post(
                    name: .cloudShareAcceptFailed,
                    object: FriendsService.friendlyMessage(for: error)
                )
            }
        }
    }
}
