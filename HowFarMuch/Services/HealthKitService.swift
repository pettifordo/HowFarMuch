import Foundation
import HealthKit

/// Read-only access to workouts in Apple Health.
final class HealthKitService {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        let readTypes: Set<HKObjectType> = [
            .workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.distanceWheelchair),
            HKQuantityType(.distanceDownhillSnowSports),
            HKQuantityType(.heartRate),
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchWorkouts(from start: Date, to end: Date = .now) async throws -> [WorkoutRecord] {
        let datePredicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(datePredicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: nil
        )
        return try await descriptor.result(for: store).map(WorkoutRecord.init)
    }
}
