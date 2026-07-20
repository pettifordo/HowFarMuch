import Foundation
import CloudKit
import Observation

/// Wraps a share for sheet presentation.
struct SharePresentation: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

@MainActor
@Observable
final class FriendsViewModel {
    var friends: [FriendsService.Friend] = []
    /// My own published feed, for comparing myself against friends per period.
    var myFeed: FriendFeed?
    /// Accepted shares whose owners haven't published a feed yet.
    var awaitingFeeds = 0
    var receivedReactions: [Reaction] = []
    var statusMessage: String?
    var isLoading = false
    var isDemo = false
    var sharePresentation: SharePresentation?
    /// Reaction just sent per friend id, for button feedback.
    var lastSentReaction: [String: ReactionKind] = [:]
    /// Asks the user for a display name (before inviting, after accepting,
    /// or when sharing is active without one).
    var showNamePrompt = false
    private var invitePendingName = false
    /// After accepting an invite: offer to share back so it's mutual.
    var showShareBackPrompt = false
    var shareBackName = "your friend"

    private let service = FriendsService()
    private let healthKit = HealthKitService()
    private var myOwnerID: String?
    /// Share created/fetched ahead of time so tapping Invite is instant.
    private var preparedShare: (share: CKShare, container: CKContainer)?
    private var didPrewarm = false

    /// Publishes my current feed (totals + reactions I've given) to CloudKit,
    /// and keeps a local copy for comparison.
    private func publishMyFeed() async throws {
        let allTime = try await healthKit.fetchWorkouts(from: .distantPast)
        let filtered = WorkoutFilters.apply(allTime).kept
        let feed = FeedBuilder.buildFeed(from: filtered)
        try await service.publish(feed: feed)
        myFeed = feed
    }

    func refresh() async {
        #if targetEnvironment(simulator)
        friends = DemoFriends.friends()
        receivedReactions = DemoFriends.receivedReactions()
        myFeed = FeedBuilder.buildFeed(from: DemoData.records(in: .allTime))
        isDemo = true
        #else
        isLoading = true
        defer { isLoading = false }
        do {
            if myOwnerID == nil { myOwnerID = try? await service.myOwnerID() }
            try await publishMyFeed()
            let result = try await service.fetchFriends()
            friends = result.friends
            awaitingFeeds = result.awaitingFeeds
            // Received reactions are the ones friends aimed at me, pulled from
            // their feeds.
            if let mine = myOwnerID {
                receivedReactions = friends
                    .flatMap(\.feed.reactionsGiven)
                    .filter { $0.targetOwnerID == mine }
                    .sorted { $0.date > $1.date }
            }
            statusMessage = nil
            // Actively sharing without a name? Friends would see "A friend".
            // (Skip while the share-back prompt is up — one dialog at a time;
            // the invite flow has its own name gate anyway.)
            if AppSettings.displayName.isEmpty && (!friends.isEmpty || awaitingFeeds > 0)
                && !showShareBackPrompt {
                showNamePrompt = true
            }
            // Prepare the share once so Invite is instant. Done inline (not a
            // detached Task) so it can't race the feed publish above and cause
            // an atomic save failure.
            if !didPrewarm && !AppSettings.displayName.isEmpty {
                didPrewarm = true
                preparedShare = try? await service.fetchOrCreateShare()
            }
        } catch {
            statusMessage = FriendsService.friendlyMessage(for: error)
        }
        #endif
    }

    /// Called after the name prompt saves: republish under the new name and
    /// continue an interrupted invite.
    func nameSaved() async {
        await refresh()
        if invitePendingName {
            invitePendingName = false
            await invite()
        }
    }

    func invite() async {
        #if targetEnvironment(simulator)
        statusMessage = "Inviting friends needs iCloud, which isn't available in the simulator."
        #else
        guard !AppSettings.displayName.isEmpty else {
            invitePendingName = true
            showNamePrompt = true
            return
        }
        // Fast path: use the pre-warmed share so the sheet appears immediately.
        if let prepared = preparedShare {
            sharePresentation = SharePresentation(share: prepared.share, container: prepared.container)
            return
        }
        do {
            let result = try await service.fetchOrCreateShare()
            preparedShare = result
            sharePresentation = SharePresentation(share: result.share, container: result.container)
        } catch {
            statusMessage = FriendsService.friendlyMessage(for: error)
        }
        #endif
    }

    func sendReaction(_ kind: ReactionKind, about period: Period, to friend: FriendsService.Friend) async {
        lastSentReaction[friend.id] = kind
        #if !targetEnvironment(simulator)
        // Record the reaction in my own list (tagged with the friend's owner id)
        // and republish my feed — the friend reads it from there.
        var given = AppSettings.reactionsGiven
        given.append(Reaction(
            id: UUID(),
            kind: kind,
            periodType: period.rawValue,
            fromName: AppSettings.displayName,
            targetOwnerID: friend.zoneID.ownerName,
            date: .now
        ))
        AppSettings.reactionsGiven = given
        do {
            try await publishMyFeed()
        } catch {
            statusMessage = FriendsService.friendlyMessage(for: error)
            lastSentReaction[friend.id] = nil
            return
        }
        #endif
        // Reset the "Sent!" state so it's clear reactions can be sent again.
        try? await Task.sleep(for: .seconds(1.5))
        if lastSentReaction[friend.id] == kind {
            lastSentReaction[friend.id] = nil
        }
    }
}
