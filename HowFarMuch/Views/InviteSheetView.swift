import SwiftUI
import CloudKit
import CoreTransferable

/// Wraps the CKShare for the system share sheet. Zone-wide shares are not
/// supported by UICloudSharingController, so invites go through ShareLink +
/// CKShareTransferRepresentation instead.
struct ShareableInvite: Transferable {
    let share: CKShare
    let container: CKContainer

    static var transferRepresentation: some TransferRepresentation {
        CKShareTransferRepresentation { invite in
            .existing(invite.share, container: invite.container)
        }
    }
}

/// The invite sheet: explains the feature and hands the iCloud collaboration
/// link to the system share sheet.
struct InviteSheetView: View {
    let share: CKShare
    let container: CKContainer

    @Environment(\.dismiss) private var dismiss

    private var shareTitle: String {
        share[CKShare.SystemFieldKey.title] as? String ?? "How Far/Much"
    }

    private var participantNames: [String] {
        share.participants
            .filter { $0.role != .owner }
            .compactMap { $0.userIdentity.nameComponents?.formatted() }
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 18) {
                LogoMarkView()
                    .frame(width: 56, height: 56)
                Text("Invite a friend")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                Text("Send an iCloud invite link. Once they accept in How Far/Much, you'll see each other's totals — and can trade Respect 🤜 and Whoops 🙈.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if !participantNames.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Already sharing with")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                        ForEach(participantNames, id: \.self) { name in
                            Label(name, systemImage: "person.fill")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.06))
                    )
                }

                ShareLink(
                    item: ShareableInvite(share: share, container: container),
                    preview: SharePreview(shareTitle)
                ) {
                    Label("Send Invite Link", systemImage: "square.and.arrow.up")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [.cyan, Color(red: 0.6, green: 0.95, blue: 0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Button("Done") { dismiss() }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .presentationBackground(Color(red: 0.05, green: 0.07, blue: 0.15))
    }
}
