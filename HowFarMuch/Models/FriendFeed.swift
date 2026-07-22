import Foundation
import HealthKit

// MARK: - The shared summary (stored as jsonb in Supabase, one row per user)

/// Everything one person shares with their friends. Values are raw numbers so
/// each viewer's own unit and compact-value settings format the display.
/// Summary only — no workout dates, times, routes, or individual sessions.
struct FriendFeed: Codable {
    var name: String
    var emoji: String
    var buckets: [PeriodBucket]

    func bucket(for period: Period) -> PeriodBucket? {
        buckets.first { $0.periodType == period.rawValue }
    }
}

struct PeriodBucket: Codable {
    /// Matches `Period.rawValue` ("Today", "Week", "Month", "Year", "All").
    var periodType: String
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

// MARK: - A friend (profile id + their shared feed)

struct Friend: Identifiable, Hashable {
    let id: UUID          // the friend's profile / user id
    let handle: String
    let feed: FriendFeed

    static func == (lhs: Friend, rhs: Friend) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
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

/// A reaction shown in the UI (resolved from the reactions table + sender name).
struct Reaction: Identifiable {
    let id: UUID
    let kind: ReactionKind
    let periodType: String
    let fromName: String
    let date: Date
}

// MARK: - Building the feed from workout records

enum FeedBuilder {
    /// Aggregates workout records into shareable period buckets, honouring the
    /// sharing preferences (Today on/off, heart rate on/off). `records` should
    /// already have settings-page rules applied (exclusions, dedupe, short).
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
                activities: aggregates,
                avgHeartRate: AppSettings.shareHeartRate ? averageHeartRate(of: inPeriod) : nil
            )
        }
        let name = AppSettings.displayName
        return FriendFeed(
            name: name.isEmpty ? "A friend" : name,
            emoji: AppSettings.displayEmoji,
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
