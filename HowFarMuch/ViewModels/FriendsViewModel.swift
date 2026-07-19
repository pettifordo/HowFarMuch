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

    func refresh() async {
        #if targetEnvironment(simulator)
        friends = DemoFriends.friends()
        receivedReactions = DemoFriends.receivedReactions()
        isDemo = true
        #else
        isLoading = true
        defer { isLoading = false }
        do {
            let allTime = try await healthKit.fetchWorkouts(from: .distantPast)
            let filtered = WorkoutFilters.apply(allTime).kept
            try await service.publish(feed: FeedBuilder.buildFeed(from: filtered))
            let result = try await service.fetchFriends()
            friends = result.friends
            awaitingFeeds = result.awaitingFeeds
            receivedReactions = try await service.fetchReceivedReactions()
            statusMessage = nil
            // Actively sharing without a name? Friends would see "A friend".
            // (Skip while the share-back prompt is up — one dialog at a time;
            // the invite flow has its own name gate anyway.)
            if AppSettings.displayName.isEmpty && (!friends.isEmpty || awaitingFeeds > 0)
                && !showShareBackPrompt {
                showNamePrompt = true
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
        do {
            let (share, container) = try await service.fetchOrCreateShare()
            sharePresentation = SharePresentation(share: share, container: container)
        } catch {
            statusMessage = FriendsService.friendlyMessage(for: error)
        }
        #endif
    }

    func sendReaction(_ kind: ReactionKind, about period: Period, to friend: FriendsService.Friend) async {
        lastSentReaction[friend.id] = kind
        #if !targetEnvironment(simulator)
        do {
            try await service.sendReaction(kind, about: period, to: friend)
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
