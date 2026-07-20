import Foundation
import CloudKit

/// CloudKit plumbing for the Friends feature.
///
/// Layout (see FRIENDS-DESIGN.md):
/// - A custom zone "FriendFeed" in the owner's private database, shared as a
///   whole via a zone-wide, **read-only** CKShare (open-by-link).
/// - One "Feed" record (name "feed") holding the owner's entire published
///   feed as JSON, including the reactions that owner has given to friends.
///
/// Nobody writes into anyone else's zone — reactions ride out in each person's
/// own feed — so friends need only read access. Every record is fetched by
/// deterministic name; no queries, no indexes.
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

    /// My CloudKit owner id — the value that appears as `zoneID.ownerName` when
    /// friends read my shared zone. Cached after the first lookup.
    func myOwnerID() async throws -> String {
        if let cached = AppSettings.cachedOwnerID { return cached }
        let id = try await container.userRecordID().recordName
        AppSettings.cachedOwnerID = id
        return id
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

    // MARK: - Sharing my feed (per-person, private)

    /// Returns the existing share for my feed record, or creates one. The share
    /// is **private** (publicPermission = .none) and attached to the single
    /// "feed" record as its root — so it can be driven by UICloudSharingController,
    /// which locks each invite to a specific person's iCloud account.
    func fetchOrCreateShare() async throws -> (share: CKShare, container: CKContainer) {
        try await ensureAccount()
        try await ensureZone()
        let name = AppSettings.displayName
        let title = name.isEmpty
            ? "How Far/Much workouts"
            : "How Far/Much — \(name)'s workouts"

        // The feed record must exist to be a share root — publish first if needed.
        let feedID = CKRecord.ID(recordName: Self.feedRecordName, zoneID: zoneID)
        let feedRecord: CKRecord
        if let existing = try? await privateDB.record(for: feedID) {
            feedRecord = existing
        } else {
            feedRecord = CKRecord(recordType: "Feed", recordID: feedID)
            feedRecord["payload"] = String(
                data: try JSONEncoder().encode(FeedBuilder.buildFeed(from: [])),
                encoding: .utf8
            )
        }

        // Reuse the existing root-record share if there is one.
        if let shareRef = feedRecord.share,
           let existingShare = try? await privateDB.record(for: shareRef.recordID) as? CKShare {
            existingShare[CKShare.SystemFieldKey.title] = title
            try? await save([existingShare], to: privateDB)
            return (existingShare, container)
        }

        // Remove any legacy zone-wide share from earlier builds to avoid conflicts.
        let legacyShareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        if (try? await privateDB.record(for: legacyShareID)) != nil {
            _ = try? await privateDB.modifyRecords(saving: [], deleting: [legacyShareID])
        }

        let share = CKShare(rootRecord: feedRecord)
        share.publicPermission = .none  // invited people only — no open link
        share[CKShare.SystemFieldKey.title] = title
        // Root record and its share must be saved together.
        let results = try await privateDB.modifyRecords(
            saving: [feedRecord, share],
            deleting: [],
            savePolicy: .changedKeys
        )
        for (_, result) in results.saveResults {
            if case .failure(let error) = result { throw error }
        }
        if let refreshed = try? await privateDB.record(for: share.recordID) as? CKShare {
            return (refreshed, container)
        }
        return (share, container)
    }

    // MARK: - Accepting an invite

    func acceptShare(metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
    }

    // MARK: - Reading friends' feeds

    /// Returns friends whose feeds I can read. With root-record sharing the
    /// feed record always exists when a share exists, so there's no separate
    /// "awaiting" state (kept at 0 for the callers).
    func fetchFriends() async throws -> (friends: [Friend], awaitingFeeds: Int) {
        try await ensureAccount()
        let zones = try await sharedDB.allRecordZones()
        var friends: [Friend] = []
        // Every shared zone in our container is a friend's feed — fetch the
        // "feed" record from each, whatever the zone is named.
        for zone in zones {
            let recordID = CKRecord.ID(recordName: Self.feedRecordName, zoneID: zone.zoneID)
            guard let record = try? await sharedDB.record(for: recordID),
                  let payload = record["payload"] as? String,
                  let feed = try? JSONDecoder().decode(FriendFeed.self, from: Data(payload.utf8)) else {
                continue
            }
            friends.append(Friend(zoneID: zone.zoneID, feed: feed))
        }
        return (friends.sorted { $0.feed.name < $1.feed.name }, 0)
    }

    // MARK: - Giving Respect / Whoops
    //
    // A reaction is just an entry in my own feed tagged with the recipient's
    // owner id (see FriendsViewModel.sendReaction, which persists it and
    // republishes). Reading them back happens in the view model too, by
    // filtering each friend's feed for reactions aimed at me — no writes into
    // anyone else's zone, so read-only sharing is enough.
}
