import Foundation
import HealthKit

// MARK: - One workout, simplified from HKWorkout

struct WorkoutRecord: Identifiable {
    let id: UUID
    let type: HKWorkoutActivityType
    let start: Date
    let duration: TimeInterval
    let distanceMeters: Double
    let energyKilocalories: Double
    /// Beats per minute, when the workout recorded heart rate (usually Apple Watch).
    let averageHeartRate: Double?
    /// Name of the app or device that recorded the workout (e.g. "Apple Watch").
    let sourceName: String?
}

extension WorkoutRecord {
    init(workout: HKWorkout) {
        var distance = 0.0
        if let distanceType = workout.workoutActivityType.distanceQuantityType,
           let sum = workout.statistics(for: distanceType)?.sumQuantity() {
            distance = sum.doubleValue(for: .meter())
        }
        var energy = 0.0
        if let sum = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() {
            energy = sum.doubleValue(for: .kilocalorie())
        }
        let heartRate = workout.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        self.init(
            id: workout.uuid,
            type: workout.workoutActivityType,
            start: workout.startDate,
            duration: workout.duration,
            distanceMeters: distance,
            energyKilocalories: energy,
            averageHeartRate: heartRate,
            sourceName: workout.sourceRevision.source.name
        )
    }
}

// MARK: - Grouping for the history drill-down

enum HistoryGrouping: String, CaseIterable, Identifiable {
    case week = "By Week"
    case month = "By Month"
    case year = "By Year"

    var id: String { rawValue }

    /// Canonical start date of the group containing `date`.
    func key(for date: Date) -> Date {
        let calendar = Calendar.current
        let component: Calendar.Component
        switch self {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return calendar.dateInterval(of: component, for: date)?.start ?? date
    }

    func title(for key: Date) -> String {
        switch self {
        case .week:
            return "Week of \(key.formatted(.dateTime.day().month(.abbreviated).year()))"
        case .month:
            return key.formatted(.dateTime.month(.wide).year())
        case .year:
            return key.formatted(.dateTime.year())
        }
    }
}
