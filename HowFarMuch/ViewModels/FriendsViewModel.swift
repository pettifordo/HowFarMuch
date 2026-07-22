import Foundation
import Observation

@MainActor
@Observable
final class FriendsViewModel {
    enum State {
        case signedOut          // needs Sign in with Apple
        case needsHandle        // signed in, no profile/handle yet
        case ready              // good to go
    }

    var state: State = .signedOut
    var myHandle: String?
    var friends: [Friend] = []
    /// My own feed, for comparing myself against friends per period.
    var myFeed: FriendFeed?
    var incoming: [SupabaseFriendsService.IncomingRequest] = []
    var outgoingCount = 0
    var receivedReactions: [Reaction] = []
    var statusMessage: String?
    var isLoading = false

    // Handle claim
    var handleDraft = ""
    var handleAvailable: Bool?
    var checkingHandle = false

    // Friend search
    var searchQuery = ""
    var searchResult: SupabaseFriendsService.ProfileRow?
    var searchStatus: String?

    /// Reaction just sent per friend id, for button feedback.
    var lastSentReaction: [String: ReactionKind] = [:]

    private let service = SupabaseFriendsService()
    private let healthKit = HealthKitService()

    /// Turn backend errors into something a user can act on — notably the
    /// clock-skew case, which otherwise surfaces as a cryptic JWT error.
    static func message(for error: Error) -> String {
        let text = "\(error)".lowercased()
        if text.contains("issued at future") || text.contains("issued in the future")
            || (text.contains("jwt") && text.contains("future")) {
            return "Your device clock looks ahead of real time, so sign-in was rejected. Turn on Settings → General → Date & Time → Set Automatically, then reopen the app."
        }
        return error.localizedDescription
    }

    // MARK: - Load

    func refresh() async {
        guard SupabaseManager.shared.isSignedIn else {
            state = .signedOut
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let profile = try await service.myProfile() else {
                state = .needsHandle
                return
            }
            // Keep local display name/emoji in step with the profile.
            AppSettings.displayName = profile.displayName
            AppSettings.displayEmoji = profile.emoji
            myHandle = profile.handle
            state = .ready

            // Build my feed for comparison; publish it if sharing is on. If
            // Health is momentarily locked, skip this cycle rather than failing —
            // loading friends from Supabase doesn't need Health at all.
            do {
                let filtered = WorkoutFilters.apply(
                    try await healthKit.fetchWorkouts(from: .distantPast)
                ).kept
                let feed = FeedBuilder.buildFeed(from: filtered)
                myFeed = feed
                if profile.sharingEnabled {
                    try await service.publishSummary(feed)
                }
            } catch {
                if !HealthKitService.isDeviceLocked(error) { throw error }
            }
            let result = try await service.loadFriends()
            friends = result.friends
            incoming = result.incoming
            outgoingCount = result.outgoingCount
            let names = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0.feed.name) })
            receivedReactions = try await service.receivedReactions(nameByID: names)
            statusMessage = nil
        } catch {
            statusMessage = Self.message(for: error)
        }
    }

    // MARK: - Handle claim

    func checkHandle() async {
        let handle = handleDraft.lowercased()
        guard handle.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil else {
            handleAvailable = false
            return
        }
        checkingHandle = true
        defer { checkingHandle = false }
        handleAvailable = try? await service.isHandleAvailable(handle)
    }

    func claimHandle() async {
        let handle = handleDraft.lowercased()
        guard handle.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil else { return }
        do {
            let name = AppSettings.displayName.isEmpty ? String(handle) : AppSettings.displayName
            try await service.saveProfile(
                handle: handle, displayName: name,
                emoji: AppSettings.displayEmoji, sharingEnabled: true
            )
            await refresh()
        } catch {
            statusMessage = Self.message(for: error)
        }
    }

    // MARK: - Search & invite

    func search() async {
        let handle = searchQuery.lowercased().replacingOccurrences(of: "@", with: "")
        searchResult = nil
        searchStatus = nil
        guard !handle.isEmpty else { return }
        do {
            if let profile = try await service.findByHandle(handle) {
                searchResult = profile
            } else {
                searchStatus = "No one found with @\(handle). Check the handle and that they've opted in."
            }
        } catch {
            searchStatus = Self.message(for: error)
        }
    }

    func sendRequest(to profile: SupabaseFriendsService.ProfileRow) async {
        do {
            try await service.sendRequest(to: profile.id)
            searchStatus = "Request sent to @\(profile.handle) 🎉"
            searchResult = nil
            await refresh()
        } catch {
            searchStatus = Self.message(for: error)
        }
    }

    func accept(_ request: SupabaseFriendsService.IncomingRequest) async {
        do {
            try await service.acceptRequest(friendshipID: request.friendshipID)
            await refresh()
        } catch {
            statusMessage = Self.message(for: error)
        }
    }

    func decline(_ request: SupabaseFriendsService.IncomingRequest) async {
        do {
            try await service.deleteFriendship(friendshipID: request.friendshipID)
            await refresh()
        } catch {
            statusMessage = Self.message(for: error)
        }
    }

    func revoke(_ friend: Friend) async {
        do {
            // Find the friendship row to delete via loadFriends bookkeeping.
            try await service.deleteFriendshipWith(userID: friend.id)
            await refresh()
        } catch {
            statusMessage = Self.message(for: error)
        }
    }

    // MARK: - Reactions

    func sendReaction(_ kind: ReactionKind, about period: Period, to friend: Friend) async {
        lastSentReaction[friend.id.uuidString] = kind
        do {
            try await service.sendReaction(kind, to: friend.id, period: period)
        } catch {
            statusMessage = Self.message(for: error)
            lastSentReaction[friend.id.uuidString] = nil
            return
        }
        try? await Task.sleep(for: .seconds(1.5))
        if lastSentReaction[friend.id.uuidString] == kind {
            lastSentReaction[friend.id.uuidString] = nil
        }
    }

    // MARK: - Account

    func signOut() async {
        await SupabaseManager.shared.signOut()
        friends = []
        incoming = []
        receivedReactions = []
        state = .signedOut
    }
}
