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
    var sharingEnabled = true
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

    /// A cancelled task (e.g. pull-to-refresh superseded by a view update) is
    /// not a real error and shouldn't be shown.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return "\(error)".lowercased().contains("cancell")
    }

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
            // For now the handle is the identity — friends see it as the name.
            myHandle = profile.handle
            sharingEnabled = profile.sharingEnabled
            AppSettings.myHandle = profile.handle
            AppSettings.displayName = profile.handle
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
            if !Self.isCancellation(error) { statusMessage = Self.message(for: error) }
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
            // Name = handle for now (identity is the handle).
            try await service.saveProfile(
                handle: handle, displayName: handle,
                emoji: AppSettings.displayEmoji, sharingEnabled: true
            )
            await refresh()
        } catch {
            let text = "\(error)".lowercased()
            if text.contains("duplicate") || text.contains("23505") {
                statusMessage = "That handle was just taken — try another."
                handleAvailable = false
            } else {
                if !Self.isCancellation(error) { statusMessage = Self.message(for: error) }
            }
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
                if profile.id == SupabaseManager.shared.currentUserID {
                    searchStatus = "That's you! 🙂 Search a friend's handle instead."
                } else if friends.contains(where: { $0.id == profile.id }) {
                    searchStatus = "You're already friends with @\(profile.handle)."
                } else {
                    searchResult = profile
                }
            } else {
                searchStatus = "No one found with @\(handle). Check the handle and that they've opted in."
            }
        } catch {
            if !Self.isCancellation(error) { searchStatus = Self.message(for: error) }
        }
    }

    func sendRequest(to profile: SupabaseFriendsService.ProfileRow) async {
        // If they've already sent me a request, accept it instead of creating
        // a second (opposite-direction) row.
        if let existing = incoming.first(where: { $0.profile.id == profile.id }) {
            await accept(existing)
            searchStatus = "You're now friends with @\(profile.handle) 🎉"
            searchResult = nil
            return
        }
        do {
            try await service.sendRequest(to: profile.id)
            searchStatus = "Request sent to @\(profile.handle) 🎉"
            searchResult = nil
            await refresh()
        } catch {
            let text = "\(error)".lowercased()
            if text.contains("duplicate") || text.contains("23505") {
                searchStatus = "You've already sent @\(profile.handle) a request."
                searchResult = nil
            } else {
                if !Self.isCancellation(error) { searchStatus = Self.message(for: error) }
            }
        }
    }

    func accept(_ request: SupabaseFriendsService.IncomingRequest) async {
        do {
            try await service.acceptRequest(friendshipID: request.friendshipID)
            await refresh()
        } catch {
            if !Self.isCancellation(error) { statusMessage = Self.message(for: error) }
        }
    }

    func decline(_ request: SupabaseFriendsService.IncomingRequest) async {
        do {
            try await service.deleteFriendship(friendshipID: request.friendshipID)
            await refresh()
        } catch {
            if !Self.isCancellation(error) { statusMessage = Self.message(for: error) }
        }
    }

    func revoke(_ friend: Friend) async {
        do {
            // Find the friendship row to delete via loadFriends bookkeeping.
            try await service.deleteFriendshipWith(userID: friend.id)
            await refresh()
        } catch {
            if !Self.isCancellation(error) { statusMessage = Self.message(for: error) }
        }
    }

    // MARK: - Reactions

    func sendReaction(_ kind: ReactionKind, about period: Period, to friend: Friend) async {
        lastSentReaction[friend.id.uuidString] = kind
        do {
            try await service.sendReaction(kind, to: friend.id, period: period)
        } catch {
            if !Self.isCancellation(error) { statusMessage = Self.message(for: error) }
            lastSentReaction[friend.id.uuidString] = nil
            return
        }
        try? await Task.sleep(for: .seconds(1.5))
        if lastSentReaction[friend.id.uuidString] == kind {
            lastSentReaction[friend.id.uuidString] = nil
        }
    }

    // MARK: - Sharing control

    /// Pause sharing (hide your totals from everyone) or resume it.
    func setSharing(_ enabled: Bool) async {
        do {
            try await service.setSharingEnabled(enabled)
            if enabled {
                if let feed = myFeed { try await service.publishSummary(feed) }
            } else {
                // Remove the published summary so friends stop seeing your totals.
                try await service.deleteMySummary()
            }
            sharingEnabled = enabled
            await refresh()
        } catch {
            if !Self.isCancellation(error) { statusMessage = Self.message(for: error) }
        }
    }

    // MARK: - Account

    /// Delete the account and all its data (profile, summary, friendships,
    /// reactions) via a server-side function, then sign out.
    func deleteAccount() async {
        do {
            try await service.deleteAccount()
            await signOut()
        } catch {
            if !Self.isCancellation(error) { statusMessage = Self.message(for: error) }
        }
    }

    func signOut() async {
        await SupabaseManager.shared.signOut()
        friends = []
        incoming = []
        receivedReactions = []
        myHandle = nil
        handleDraft = ""
        handleAvailable = nil
        searchResult = nil
        searchStatus = nil
        statusMessage = nil
        outgoingCount = 0
        state = .signedOut
    }
}
