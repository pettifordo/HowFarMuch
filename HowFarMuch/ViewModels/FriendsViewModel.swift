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
    var receivedReactions: [Reaction] = []
    var statusMessage: String?
    var isLoading = false
    var isDemo = false
    var sharePresentation: SharePresentation?
    /// Reaction just sent per friend id, for button feedback.
    var lastSentReaction: [String: ReactionKind] = [:]

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
            friends = try await service.fetchFriends()
            receivedReactions = try await service.fetchReceivedReactions()
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
        #endif
    }

    func invite() async {
        #if targetEnvironment(simulator)
        statusMessage = "Inviting friends needs iCloud, which isn't available in the simulator."
        #else
        do {
            let (share, container) = try await service.fetchOrCreateShare()
            sharePresentation = SharePresentation(share: share, container: container)
        } catch {
            statusMessage = error.localizedDescription
        }
        #endif
    }

    func sendReaction(_ kind: ReactionKind, about period: Period, to friend: FriendsService.Friend) async {
        lastSentReaction[friend.id] = kind
        #if !targetEnvironment(simulator)
        do {
            try await service.sendReaction(kind, about: period, to: friend)
        } catch {
            statusMessage = error.localizedDescription
            lastSentReaction[friend.id] = nil
        }
        #endif
    }
}
