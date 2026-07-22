import Foundation
import Supabase

/// All Friends data access against Supabase. Security is enforced server-side
/// by Row-Level Security; this layer just makes the calls.
@MainActor
struct SupabaseFriendsService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Row types (snake_case columns)

    struct ProfileRow: Decodable {
        let id: UUID
        let handle: String
        let displayName: String
        let emoji: String
        let sharingEnabled: Bool

        enum CodingKeys: String, CodingKey {
            case id, handle, emoji
            case displayName = "display_name"
            case sharingEnabled = "sharing_enabled"
        }

        // The handle-search RPC returns only id/handle/name/emoji (no
        // sharing_enabled — those results are opted-in by definition), so
        // default it rather than failing to decode.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            handle = try c.decode(String.self, forKey: .handle)
            displayName = try c.decode(String.self, forKey: .displayName)
            emoji = try c.decode(String.self, forKey: .emoji)
            sharingEnabled = try c.decodeIfPresent(Bool.self, forKey: .sharingEnabled) ?? true
        }
    }

    private struct ProfileUpsert: Encodable {
        let id: UUID
        let handle: String
        let displayName: String
        let emoji: String
        let sharingEnabled: Bool
        enum CodingKeys: String, CodingKey {
            case id, handle, emoji
            case displayName = "display_name"
            case sharingEnabled = "sharing_enabled"
        }
    }

    private struct SummaryUpsert: Encodable {
        let userId: UUID
        let payload: FriendFeed
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case payload
        }
    }

    private struct SummaryRow: Decodable {
        let userId: UUID
        let payload: FriendFeed
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case payload
        }
    }

    struct FriendshipRow: Decodable {
        let id: UUID
        let requesterId: UUID
        let addresseeId: UUID
        let status: String
        enum CodingKeys: String, CodingKey {
            case id, status
            case requesterId = "requester_id"
            case addresseeId = "addressee_id"
        }
    }

    private struct FriendshipInsert: Encodable {
        let requesterId: UUID
        let addresseeId: UUID
        let status: String
        enum CodingKeys: String, CodingKey {
            case status
            case requesterId = "requester_id"
            case addresseeId = "addressee_id"
        }
    }

    private struct ReactionInsert: Encodable {
        let fromId: UUID
        let toId: UUID
        let kind: String
        let periodType: String
        enum CodingKeys: String, CodingKey {
            case kind
            case fromId = "from_id"
            case toId = "to_id"
            case periodType = "period_type"
        }
    }

    private struct ReactionRow: Decodable {
        let id: UUID
        let fromId: UUID
        let toId: UUID
        let kind: String
        let periodType: String
        let createdAt: Date
        enum CodingKeys: String, CodingKey {
            case id, kind
            case fromId = "from_id"
            case toId = "to_id"
            case periodType = "period_type"
            case createdAt = "created_at"
        }
    }

    // MARK: - Profile & handle

    func myProfile() async throws -> ProfileRow? {
        guard let uid = SupabaseManager.shared.currentUserID else { return nil }
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().eq("id", value: uid.uuidString).execute().value
        return rows.first
    }

    func isHandleAvailable(_ handle: String) async throws -> Bool {
        try await client.rpc("is_handle_available", params: ["p_handle": handle.lowercased()])
            .execute().value
    }

    /// Create or update my profile (claims the handle on first save).
    func saveProfile(handle: String, displayName: String, emoji: String, sharingEnabled: Bool) async throws {
        guard let uid = SupabaseManager.shared.currentUserID else { return }
        let row = ProfileUpsert(
            id: uid, handle: handle.lowercased(), displayName: displayName,
            emoji: emoji, sharingEnabled: sharingEnabled
        )
        try await client.from("profiles").upsert(row).execute()
    }

    func setSharingEnabled(_ enabled: Bool) async throws {
        guard let uid = SupabaseManager.shared.currentUserID else { return }
        try await client.from("profiles")
            .update(["sharing_enabled": enabled])
            .eq("id", value: uid.uuidString).execute()
    }

    // MARK: - Publishing my summary

    func publishSummary(_ feed: FriendFeed) async throws {
        guard let uid = SupabaseManager.shared.currentUserID else { return }
        try await client.from("summaries").upsert(SummaryUpsert(userId: uid, payload: feed)).execute()
    }

    // MARK: - Finding & inviting

    func findByHandle(_ handle: String) async throws -> ProfileRow? {
        let rows: [ProfileRow] = try await client.rpc(
            "find_profile_by_handle", params: ["p_handle": handle.lowercased()]
        ).execute().value
        return rows.first
    }

    func sendRequest(to addresseeID: UUID) async throws {
        guard let uid = SupabaseManager.shared.currentUserID else { return }
        try await client.from("friendships")
            .insert(FriendshipInsert(requesterId: uid, addresseeId: addresseeID, status: "pending"))
            .execute()
    }

    func acceptRequest(friendshipID: UUID) async throws {
        try await client.from("friendships")
            .update(["status": "accepted"])
            .eq("id", value: friendshipID.uuidString).execute()
    }

    func deleteFriendship(friendshipID: UUID) async throws {
        try await client.from("friendships")
            .delete().eq("id", value: friendshipID.uuidString).execute()
    }

    /// Revoke: delete the accepted friendship between me and another user
    /// (either direction).
    func deleteFriendshipWith(userID: UUID) async throws {
        guard let uid = SupabaseManager.shared.currentUserID else { return }
        let a = uid.uuidString
        let b = userID.uuidString
        try await client.from("friendships").delete().or(
            "and(requester_id.eq.\(a),addressee_id.eq.\(b)),and(requester_id.eq.\(b),addressee_id.eq.\(a))"
        ).execute()
    }

    // MARK: - Loading friendships

    private func friendships() async throws -> [FriendshipRow] {
        try await client.from("friendships").select().execute().value
    }

    private func profiles(ids: [UUID]) async throws -> [ProfileRow] {
        guard !ids.isEmpty else { return [] }
        return try await client.from("profiles")
            .select().in("id", values: ids.map(\.uuidString)).execute().value
    }

    private func summaries(ids: [UUID]) async throws -> [UUID: FriendFeed] {
        guard !ids.isEmpty else { return [:] }
        let rows: [SummaryRow] = try await client.from("summaries")
            .select().in("user_id", values: ids.map(\.uuidString)).execute().value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.userId, $0.payload) })
    }

    /// A pending friend request I've received.
    struct IncomingRequest: Identifiable {
        let friendshipID: UUID
        let profile: ProfileRow
        var id: UUID { friendshipID }
    }

    struct FriendsResult {
        var friends: [Friend]
        var incoming: [IncomingRequest]
        var outgoingCount: Int
    }

    func loadFriends() async throws -> FriendsResult {
        guard let uid = SupabaseManager.shared.currentUserID else {
            return FriendsResult(friends: [], incoming: [], outgoingCount: 0)
        }
        let all = try await friendships()

        // Accepted friendships → the other party is a friend.
        let accepted = all.filter { $0.status == "accepted" }
        let friendIDs = accepted.map { $0.requesterId == uid ? $0.addresseeId : $0.requesterId }

        // Pending requests I received (I'm the addressee).
        let incomingRows = all.filter { $0.status == "pending" && $0.addresseeId == uid }
        let outgoingCount = all.filter { $0.status == "pending" && $0.requesterId == uid }.count

        let neededProfiles = Set(friendIDs + incomingRows.map(\.requesterId))
        let profileList = try await profiles(ids: Array(neededProfiles))
        let profileByID = Dictionary(uniqueKeysWithValues: profileList.map { ($0.id, $0) })
        let feeds = try await summaries(ids: friendIDs)

        let friends: [Friend] = friendIDs.compactMap { fid in
            guard let profile = profileByID[fid], let feed = feeds[fid] else { return nil }
            return Friend(id: fid, handle: profile.handle, feed: feed)
        }.sorted { $0.feed.name < $1.feed.name }

        let incoming: [IncomingRequest] = incomingRows.compactMap { row in
            guard let profile = profileByID[row.requesterId] else { return nil }
            return IncomingRequest(friendshipID: row.id, profile: profile)
        }
        return FriendsResult(friends: friends, incoming: incoming, outgoingCount: outgoingCount)
    }

    // MARK: - Reactions

    func sendReaction(_ kind: ReactionKind, to friendID: UUID, period: Period) async throws {
        guard let uid = SupabaseManager.shared.currentUserID else { return }
        try await client.from("reactions").insert(ReactionInsert(
            fromId: uid, toId: friendID, kind: kind.rawValue, periodType: period.rawValue
        )).execute()
    }

    func receivedReactions(nameByID: [UUID: String]) async throws -> [Reaction] {
        guard let uid = SupabaseManager.shared.currentUserID else { return [] }
        let rows: [ReactionRow] = try await client.from("reactions")
            .select().eq("to_id", value: uid.uuidString)
            .order("created_at", ascending: false).limit(20).execute().value
        return rows.compactMap { row in
            guard let kind = ReactionKind(rawValue: row.kind) else { return nil }
            return Reaction(
                id: row.id, kind: kind, periodType: row.periodType,
                fromName: nameByID[row.fromId] ?? "A friend", date: row.createdAt
            )
        }
    }
}
