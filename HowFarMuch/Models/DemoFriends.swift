import Foundation
import CloudKit

/// Fake friends so the Friends UI is visible in the simulator, where iCloud
/// isn't signed in. Clearly badged in the UI.
enum DemoFriends {
    static func friends() -> [FriendsService.Friend] {
        [
            friend(name: "Cally", emoji: "🏊‍♀️", owner: "_demoCally", scale: 0.85, heartRate: 138),
            friend(name: "Steve", emoji: "🚴", owner: "_demoSteve", scale: 1.2, heartRate: 128),
        ]
    }

    static func receivedReactions() -> [Reaction] {
        [
            Reaction(id: UUID(), kind: .respect, periodType: Period.week.rawValue,
                     fromName: "Cally", date: Date().addingTimeInterval(-2 * 3600)),
            Reaction(id: UUID(), kind: .whoops, periodType: Period.today.rawValue,
                     fromName: "Steve", date: Date().addingTimeInterval(-26 * 3600)),
        ]
    }

    private static func friend(
        name: String,
        emoji: String,
        owner: String,
        scale: Double,
        heartRate: Double
    ) -> FriendsService.Friend {
        let records = DemoData.records(in: .allTime)
        let periods: [Period] = [.today, .week, .month, .year, .allTime]
        let buckets = periods.map { period -> PeriodBucket in
            let inPeriod = records.filter { $0.start >= period.startDate }
            let aggregates = ActivityStats.aggregate(inPeriod).map { stats in
                ActivityAggregate(
                    typeRaw: stats.type.rawValue,
                    distanceMeters: stats.totalDistanceMeters * scale,
                    durationSeconds: stats.totalDuration * scale,
                    kilocalories: stats.totalEnergyKilocalories * scale,
                    workoutCount: max(1, Int((Double(stats.workoutCount) * scale).rounded()))
                )
            }
            return PeriodBucket(
                periodType: period.rawValue,
                start: period.startDate,
                activities: aggregates,
                avgHeartRate: heartRate
            )
        }
        return FriendsService.Friend(
            zoneID: CKRecordZone.ID(zoneName: FriendsService.zoneName, ownerName: owner),
            feed: FriendFeed(
                name: name,
                emoji: emoji,
                updated: Date().addingTimeInterval(-Double.random(in: 600...20_000)),
                buckets: buckets
            )
        )
    }
}
