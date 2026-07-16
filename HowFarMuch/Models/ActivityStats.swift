import Foundation
import HealthKit
import SwiftUI

// MARK: - Aggregated totals for one activity type

struct ActivityStats: Identifiable {
    let type: HKWorkoutActivityType
    var workoutCount: Int = 0
    var totalDuration: TimeInterval = 0
    var totalDistanceMeters: Double = 0
    var totalEnergyKilocalories: Double = 0

    var id: UInt { type.rawValue }

    static func aggregate(_ workouts: [WorkoutRecord]) -> [ActivityStats] {
        var byType: [UInt: ActivityStats] = [:]
        for workout in workouts {
            let key = workout.type.rawValue
            var stats = byType[key] ?? ActivityStats(type: workout.type)
            stats.workoutCount += 1
            stats.totalDuration += workout.duration
            stats.totalDistanceMeters += workout.distanceMeters
            stats.totalEnergyKilocalories += workout.energyKilocalories
            byType[key] = stats
        }
        return byType.values.sorted { $0.totalDuration > $1.totalDuration }
    }
}

// MARK: - Time window

enum Period: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case allTime = "All"

    var id: String { rawValue }

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            return .distantPast
        }
    }

    var phrase: String {
        switch self {
        case .today: return "today"
        case .week: return "in the last 7 days"
        case .month: return "in the last month"
        case .year: return "in the last year"
        case .allTime: return "all time"
        }
    }

    /// Sensible drill-down grouping for this window.
    var defaultGrouping: HistoryGrouping {
        switch self {
        case .today, .week, .month: return .week
        case .year: return .month
        case .allTime: return .year
        }
    }
}

// MARK: - Which question we're answering

enum Metric: String, CaseIterable, Identifiable {
    case far = "How Far"
    case long = "How Long"
    case much = "How Much"
    case many = "How Many"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .far: return "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .long: return "clock.fill"
        case .much: return "flame.fill"
        case .many: return "number"
        }
    }

    func value(from stats: ActivityStats) -> Double {
        switch self {
        case .far: return stats.totalDistanceMeters
        case .long: return stats.totalDuration
        case .much: return stats.totalEnergyKilocalories
        case .many: return Double(stats.workoutCount)
        }
    }

    func formatted(_ value: Double) -> String {
        let compact = AppSettings.compactValues
        switch self {
        case .far:
            let measurement = Measurement(value: value, unit: UnitLength.meters)
                .converted(to: AppSettings.resolvedDistanceUnit)
            if compact && measurement.value >= 10_000 {
                return "\(ValueFormatting.compactNumber(measurement.value)) \(AppSettings.distanceUnitAbbreviation)"
            }
            return measurement.formatted(.measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0...1))
            ))
        case .long:
            return ValueFormatting.duration(value, compact: compact)
        case .much:
            if compact && value >= 10_000 {
                return "\(ValueFormatting.compactNumber(value)) kcal"
            }
            return "\(Int(value.rounded()).formatted()) kcal"
        case .many:
            let count = Int(value)
            if compact && value >= 10_000 {
                return "\(ValueFormatting.compactNumber(value)) workouts"
            }
            return count == 1 ? "1 workout" : "\(count.formatted()) workouts"
        }
    }
}

// MARK: - Presentation info per activity type

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .functionalStrengthTraining: return "Functional Strength"
        case .traditionalStrengthTraining: return "Strength Training"
        case .coreTraining: return "Core Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .crossTraining: return "Cross Training"
        case .mixedCardio: return "Mixed Cardio"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .flexibility: return "Flexibility"
        case .mindAndBody: return "Mind & Body"
        case .cooldown: return "Cooldown"
        case .tennis: return "Tennis"
        case .golf: return "Golf"
        case .soccer: return "Football"
        case .basketball: return "Basketball"
        case .cricket: return "Cricket"
        case .badminton: return "Badminton"
        case .squash: return "Squash"
        case .tableTennis: return "Table Tennis"
        case .pickleball: return "Pickleball"
        case .paddleSports: return "Paddle Sports"
        case .surfingSports: return "Surfing"
        case .sailing: return "Sailing"
        case .downhillSkiing: return "Downhill Skiing"
        case .crossCountrySkiing: return "Cross-Country Skiing"
        case .snowboarding: return "Snowboarding"
        case .skatingSports: return "Skating"
        case .martialArts: return "Martial Arts"
        case .boxing: return "Boxing"
        case .climbing: return "Climbing"
        case .dance: return "Dance"
        case .cardioDance: return "Cardio Dance"
        case .jumpRope: return "Jump Rope"
        case .wheelchairWalkPace, .wheelchairRunPace: return "Wheelchair"
        default: return "Other"
        }
    }

    var symbolName: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .rowing: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .stairClimbing: return "figure.stairs"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .coreTraining: return "figure.core.training"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .crossTraining, .mixedCardio: return "figure.cross.training"
        case .yoga: return "figure.yoga"
        case .pilates: return "figure.pilates"
        case .flexibility, .cooldown: return "figure.cooldown"
        case .mindAndBody: return "figure.mind.and.body"
        case .tennis: return "figure.tennis"
        case .golf: return "figure.golf"
        case .soccer: return "figure.soccer"
        case .basketball: return "figure.basketball"
        case .cricket: return "figure.cricket"
        case .badminton: return "figure.badminton"
        case .squash: return "figure.squash"
        case .tableTennis: return "figure.table.tennis"
        case .pickleball: return "figure.pickleball"
        case .paddleSports: return "oar.2.crossed"
        case .surfingSports: return "figure.surfing"
        case .sailing: return "sailboat.fill"
        case .downhillSkiing, .crossCountrySkiing: return "figure.skiing.downhill"
        case .snowboarding: return "figure.snowboarding"
        case .skatingSports: return "figure.ice.skating"
        case .martialArts: return "figure.martial.arts"
        case .boxing: return "figure.boxing"
        case .climbing: return "figure.climbing"
        case .dance, .cardioDance: return "figure.dance"
        case .jumpRope: return "figure.jumprope"
        case .wheelchairWalkPace, .wheelchairRunPace: return "figure.roll"
        default: return "figure.mixed.cardio"
        }
    }

    var tint: Color {
        switch self {
        case .running: return .orange
        case .walking: return .mint
        case .hiking: return .green
        case .cycling: return .yellow
        case .swimming: return .cyan
        case .rowing, .paddleSports, .surfingSports, .sailing: return .teal
        case .functionalStrengthTraining, .traditionalStrengthTraining, .coreTraining: return .red
        case .highIntensityIntervalTraining, .boxing, .martialArts: return .pink
        case .yoga, .pilates, .mindAndBody, .flexibility, .cooldown: return .purple
        case .tennis, .badminton, .squash, .tableTennis, .pickleball: return .indigo
        case .golf: return .green
        case .downhillSkiing, .crossCountrySkiing, .snowboarding, .skatingSports: return .blue
        case .dance, .cardioDance: return .pink
        default: return .blue
        }
    }

    /// The distance quantity type that this activity's distance is recorded under, if any.
    var distanceQuantityType: HKQuantityType? {
        switch self {
        case .running, .walking, .hiking, .elliptical, .stairClimbing, .crossTraining, .mixedCardio:
            return HKQuantityType(.distanceWalkingRunning)
        case .cycling:
            return HKQuantityType(.distanceCycling)
        case .swimming:
            return HKQuantityType(.distanceSwimming)
        case .wheelchairWalkPace, .wheelchairRunPace:
            return HKQuantityType(.distanceWheelchair)
        case .downhillSkiing, .snowboarding:
            return HKQuantityType(.distanceDownhillSnowSports)
        default:
            return nil
        }
    }
}
