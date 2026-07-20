import SwiftUI
import CloudKit
import UIKit

/// Apple's native sharing UI for the feed's root-record share. Because the
/// share is private (publicPermission = .none) with only `.allowPrivate` /
/// `.allowReadOnly` offered, each invite is locked to the specific person's
/// iCloud account — a forwarded link won't work for anyone else. This screen
/// also manages participants and "Stop Sharing" for free.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var onStopped: () -> Void = {}

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPrivate, .allowReadOnly]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(share: share, onStopped: onStopped)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let share: CKShare
        let onStopped: () -> Void

        init(share: CKShare, onStopped: @escaping () -> Void) {
            self.share = share
            self.onStopped = onStopped
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {}

        func itemTitle(for csc: UICloudSharingController) -> String? {
            share[CKShare.SystemFieldKey.title] as? String ?? "How Far/Much"
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            onStopped()
        }
    }
}
