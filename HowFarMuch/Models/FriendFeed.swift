import Foundation
import HealthKit

// MARK: - The published feed (one JSON record per person in CloudKit)

/// Everything one person shares with their friends. Values are raw numbers so
/// each viewer's own unit and compact-value settings format the display.
struct FriendFeed: Codable {
    var name: String
    var emoji: String
    var updated: Date
    var buckets: [PeriodBucket]

    func bucket(for period: Period) -> PeriodBucket? {
        buckets.first { $0.periodType == period.rawValue }
    }
}

struct PeriodBucket: Codable {
    /// Matches `Period.rawValue` ("Today", "Week", "Month", "Year", "All").
    var periodType: String
    var start: Date
    var activities: [ActivityAggregate]
    /// Time-weighted average across the period, if shared.
    var avgHeartRate: Double?

    var totalDistanceMeters: Double { activities.reduce(0) { $0 + $1.distanceMeters } }
    var totalDurationSeconds: Double { activities.reduce(0) { $0 + $1.durationSeconds } }
    var totalKilocalories: Double { activities.reduce(0) { $0 + $1.kilocalories } }
    var totalWorkouts: Int { activities.reduce(0) { $0 + $1.workoutCount } }
}

struct ActivityAggregate: Codable, Identifiable {
    var typeRaw: UInt
    var distanceMeters: Double
    var durationSeconds: Double
    var kilocalories: Double
    var workoutCount: Int

    var id: UInt { typeRaw }
    var type: HKWorkoutActivityType { HKWorkoutActivityType(rawValue: typeRaw) ?? .other }
}

// MARK: - Reactions

enum ReactionKind: String, Codable, CaseIterable {
    case respect
    case whoops

    var emoji: String {
        switch self {
        case .respect: return "🤜"
        case .whoops: return "🙈"
        }
    }

    var label: String {
        switch self {
        case .respect: return "Respect"
        case .whoops: return "Whoops"
        }
    }
}

struct Reaction: Codable, Identifiable {
    var id: UUID
    var kind: ReactionKind
    /// Which period the reaction was about (Period.rawValue).
    var periodType: String
    var fromName: String
    var date: Date
}

// MARK: - Building the feed from workout records

enum FeedBuilder {
    /// Aggregates all-time workout records into shareable period buckets,
    /// honouring the sharing preferences (Today on/off, heart rate on/off).
    /// `records` should already have settings-page rules applied (exclusions,
    /// dedupe, short workouts) so friends see what the owner sees.
    static func buildFeed(from records: [WorkoutRecord]) -> FriendFeed {
        var periods: [Period] = [.week, .month, .year, .allTime]
        if AppSettings.shareToday {
            periods.insert(.today, at: 0)
        }
        let buckets = periods.map { period -> PeriodBucket in
            let inPeriod = records.filter { $0.start >= period.startDate }
            let aggregates = ActivityStats.aggregate(inPeriod).map { stats in
                ActivityAggregate(
                    typeRaw: stats.type.rawValue,
                    distanceMeters: stats.totalDistanceMeters,
                    durationSeconds: stats.totalDuration,
                    kilocalories: stats.totalEnergyKilocalories,
                    workoutCount: stats.workoutCount
                )
            }
            return PeriodBucket(
                periodType: period.rawValue,
                start: period.startDate,
                activities: aggregates,
                avgHeartRate: AppSettings.shareHeartRate ? averageHeartRate(of: inPeriod) : nil
            )
        }
        return FriendFeed(
            name: AppSettings.displayName,
            emoji: AppSettings.displayEmoji,
            updated: .now,
            buckets: buckets
        )
    }

    static func averageHeartRate(of records: [WorkoutRecord]) -> Double? {
        let withHeartRate = records.filter { $0.averageHeartRate != nil && $0.duration > 0 }
        let totalTime = withHeartRate.reduce(0) { $0 + $1.duration }
        guard totalTime > 0 else { return nil }
        return withHeartRate.reduce(0) { $0 + ($1.averageHeartRate ?? 0) * $1.duration } / totalTime
    }
}
