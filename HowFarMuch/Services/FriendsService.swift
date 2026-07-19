import Foundation
import CloudKit

/// CloudKit plumbing for the Friends feature.
///
/// Layout (see FRIENDS-DESIGN.md):
/// - A custom zone "FriendFeed" in the owner's private database, shared as a
///   whole via a zone-wide CKShare with read/write participants.
/// - One "Feed" record (name "feed") holding the owner's entire published
///   feed as JSON.
/// - One "ReactionLog" record per participant (name "reactions|<userID>"),
///   written by that participant — single writer per record, so no conflicts.
///
/// Every record is fetched by deterministic name; no queries, no indexes.
final class FriendsService {
    enum FriendsError: LocalizedError {
        case notSignedIn
        case restricted

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Sign in to iCloud in Settings to share with friends."
            case .restricted:
                return "This iCloud account can't use sharing (it may be managed or restricted)."
            }
        }
    }

    /// A friend's feed plus the zone it lives in (needed to write reactions back).
    struct Friend: Identifiable, Hashable {
        let zoneID: CKRecordZone.ID
        let feed: FriendFeed
        var id: String { "\(zoneID.ownerName)|\(zoneID.zoneName)" }

        static func == (lhs: Friend, rhs: Friend) -> Bool {
            lhs.id == rhs.id && lhs.feed.updated == rhs.feed.updated
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    static let containerID = "iCloud.com.owenpettiford.HowFarMuch"
    static let zoneName = "FriendFeed"
    private static let feedRecordName = "feed"

    private let container = CKContainer(identifier: FriendsService.containerID)
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Saving (modifyRecords does NOT throw for per-record failures —
    // they come back in the results and must be surfaced explicitly)

    private func save(_ records: [CKRecord], to database: CKDatabase) async throws {
        let results = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .changedKeys
        )
        for (_, result) in results.saveResults {
            if case .failure(let error) = result { throw error }
        }
    }

    /// Maps raw CloudKit errors to messages a user can act on.
    static func friendlyMessage(for error: Error) -> String {
        guard let ckError = error as? CKError else { return error.localizedDescription }
        switch ckError.code {
        case .quotaExceeded:
            return "Your iCloud storage is full — sharing needs a small amount of free space. (Settings → your name → iCloud)"
        case .networkUnavailable, .networkFailure:
            return "No connection to iCloud — check your internet and try again."
        case .notAuthenticated:
            return "Sign in to iCloud in Settings to share with friends."
        case .permissionFailure:
            return "iCloud refused permission for this action (CloudKit error 10)."
        default:
            return "CloudKit error \(ckError.code.rawValue): \(ckError.localizedDescription)"
        }
    }

    // MARK: - Account

    func ensureAccount() async throws {
        switch try await container.accountStatus() {
        case .available:
            return
        case .restricted:
            throw FriendsError.restricted
        default:
            throw FriendsError.notSignedIn
        }
    }

    // MARK: - Publishing my feed

    func publish(feed: FriendFeed) async throws {
        try await ensureAccount()
        try await ensureZone()
        let recordID = CKRecord.ID(recordName: Self.feedRecordName, zoneID: zoneID)
        let record: CKRecord
        if let existing = try? await privateDB.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: "Feed", recordID: recordID)
        }
        record["payload"] = String(data: try JSONEncoder().encode(feed), encoding: .utf8)
        record["updated"] = feed.updated
        try await save([record], to: privateDB)
    }

    private func ensureZone() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        let results = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
        for (_, result) in results.saveResults {
            if case .failure(let error) = result { throw error }
        }
    }

    // MARK: - Sharing my zone

    /// Returns the existing zone-wide share, or creates one, for use with
    /// UICloudSharingController.
    func fetchOrCreateShare() async throws -> (CKShare, CKContainer) {
        try await ensureAccount()
        try await ensureZone()
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        let name = AppSettings.displayName
        let title = name.isEmpty
            ? "How Far/Much workouts"
            : "How Far/Much — \(name)'s workouts"
        if let existing = try? await privateDB.record(for: shareID) as? CKShare {
            // Keep the title and permission current, then re-fetch so the
            // record carries the server-generated share URL.
            existing[CKShare.SystemFieldKey.title] = title
            existing.publicPermission = .readWrite
            try await save([existing], to: privateDB)
            if let refreshed = try? await privateDB.record(for: shareID) as? CKShare {
                return (refreshed, container)
            }
            return (existing, container)
        }
        let share = CKShare(recordZoneID: zoneID)
        // Open-by-link: the URL itself is the invitation. Avoids the fragile
        // per-recipient participant registration in the Messages flow.
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = title
        try await save([share], to: privateDB)
        if let refreshed = try? await privateDB.record(for: shareID) as? CKShare {
            return (refreshed, container)
        }
        return (share, container)
    }

    // MARK: - Accepting an invite

    func acceptShare(metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
    }

    // MARK: - Reading friends' feeds

    /// Returns friends with published feeds, plus how many accepted shares are
    /// still waiting for their owner to open the app and publish.
    func fetchFriends() async throws -> (friends: [Friend], awaitingFeeds: Int) {
        try await ensureAccount()
        let zones = try await sharedDB.allRecordZones()
        var friends: [Friend] = []
        var awaiting = 0
        for zone in zones where zone.zoneID.zoneName == Self.zoneName {
            let recordID = CKRecord.ID(recordName: Self.feedRecordName, zoneID: zone.zoneID)
            guard let record = try? await sharedDB.record(for: recordID),
                  let payload = record["payload"] as? String,
                  let feed = try? JSONDecoder().decode(FriendFeed.self, from: Data(payload.utf8)) else {
                awaiting += 1
                continue
            }
            friends.append(Friend(zoneID: zone.zoneID, feed: feed))
        }
        return (friends.sorted { $0.feed.name < $1.feed.name }, awaiting)
    }

    // MARK: - Giving Respect / Whoops

    private func myReactionRecordID(in zoneID: CKRecordZone.ID) async throws -> CKRecord.ID {
        let userID = try await container.userRecordID()
        return CKRecord.ID(recordName: "reactions|\(userID.recordName)", zoneID: zoneID)
    }

    /// Appends a reaction to my log inside the friend's shared zone.
    func sendReaction(_ kind: ReactionKind, about period: Period, to friend: Friend) async throws {
        try await ensureAccount()
        let recordID = try await myReactionRecordID(in: friend.zoneID)
        let record: CKRecord
        var log: [Reaction] = []
        if let existing = try? await sharedDB.record(for: recordID) {
            record = existing
            if let payload = record["payload"] as? String,
               let decoded = try? JSONDecoder().decode([Reaction].self, from: Data(payload.utf8)) {
                log = decoded
            }
        } else {
            record = CKRecord(recordType: "ReactionLog", recordID: recordID)
        }
        log.append(Reaction(
            id: UUID(),
            kind: kind,
            periodType: period.rawValue,
            fromName: AppSettings.displayName,
            date: .now
        ))
        // Keep the log bounded.
        if log.count > 50 { log.removeFirst(log.count - 50) }
        record["payload"] = String(data: try JSONEncoder().encode(log), encoding: .utf8)
        try await save([record], to: sharedDB)
    }

    // MARK: - Reactions I've received

    /// Reads every participant's reaction log from my own zone.
    func fetchReceivedReactions() async throws -> [Reaction] {
        try await ensureAccount()
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        guard let share = try? await privateDB.record(for: shareID) as? CKShare else {
            return []
        }
        var reactions: [Reaction] = []
        for participant in share.participants where participant.role != .owner {
            guard let userID = participant.userIdentity.userRecordID else { continue }
            let recordID = CKRecord.ID(recordName: "reactions|\(userID.recordName)", zoneID: zoneID)
            guard let record = try? await privateDB.record(for: recordID),
                  let payload = record["payload"] as? String,
                  let log = try? JSONDecoder().decode([Reaction].self, from: Data(payload.utf8)) else {
                continue
            }
            reactions.append(contentsOf: log)
        }
        return reactions.sorted { $0.date > $1.date }
    }
}
