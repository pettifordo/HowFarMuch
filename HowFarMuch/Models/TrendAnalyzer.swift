import Foundation

// MARK: - One observed trend (e.g. "Pace: getting faster")

struct TrendFinding: Identifiable {
    let title: String
    let symbolName: String
    let earlierText: String
    let laterText: String
    /// Signed fractional change from the earlier half to the later half.
    let percentChange: Double
    let isGood: Bool
    let verdict: String

    var id: String { title }
    var isNeutral: Bool { abs(percentChange) < 0.01 }
}

// MARK: - Splits a workout history in half and compares the halves

enum TrendAnalyzer {
    static let minimumWorkouts = 4

    static var distanceUnit: UnitLength {
        AppSettings.resolvedDistanceUnit
    }

    static var distanceUnitAbbreviation: String {
        AppSettings.distanceUnitAbbreviation
    }

    static func findings(for workouts: [WorkoutRecord]) -> [TrendFinding] {
        let sorted = workouts.sorted { $0.start < $1.start }
        guard sorted.count >= minimumWorkouts else { return [] }
        let mid = sorted.count / 2
        let earlier = Array(sorted[..<mid])
        let later = Array(sorted[mid...])
        var findings: [TrendFinding] = []

        if let earlierPace = averagePace(of: earlier), let laterPace = averagePace(of: later) {
            let change = (laterPace - earlierPace) / earlierPace
            findings.append(TrendFinding(
                title: "Pace",
                symbolName: "speedometer",
                earlierText: paceText(earlierPace),
                laterText: paceText(laterPace),
                percentChange: change,
                isGood: change <= 0,
                verdict: verdict(change: change, betterWhenLower: true,
                                 up: "Slowing down", down: "Getting faster")
            ))
        }

        let earlierDuration = averageDuration(of: earlier)
        let laterDuration = averageDuration(of: later)
        if earlierDuration > 0 {
            let change = (laterDuration - earlierDuration) / earlierDuration
            findings.append(TrendFinding(
                title: "Duration",
                symbolName: "clock.fill",
                earlierText: Metric.long.formatted(earlierDuration),
                laterText: Metric.long.formatted(laterDuration),
                percentChange: change,
                isGood: change >= 0,
                verdict: verdict(change: change, betterWhenLower: false,
                                 up: "Going longer", down: "Going shorter")
            ))
        }

        let earlierEnergy = averageEnergy(of: earlier)
        let laterEnergy = averageEnergy(of: later)
        if earlierEnergy > 0 && laterEnergy > 0 {
            let change = (laterEnergy - earlierEnergy) / earlierEnergy
            findings.append(TrendFinding(
                title: "Calories",
                symbolName: "flame.fill",
                earlierText: Metric.much.formatted(earlierEnergy),
                laterText: Metric.much.formatted(laterEnergy),
                percentChange: change,
                isGood: change >= 0,
                verdict: verdict(change: change, betterWhenLower: false,
                                 up: "Burning more", down: "Burning less")
            ))
        }

        return findings
    }

    private static func verdict(change: Double, betterWhenLower: Bool, up: String, down: String) -> String {
        if abs(change) < 0.01 { return "Holding steady" }
        return change > 0 ? up : down
    }

    /// Time-weighted average pace in seconds per km/mi, or nil if no distance was covered.
    private static func averagePace(of workouts: [WorkoutRecord]) -> Double? {
        let moving = workouts.filter { $0.distanceMeters > 0 && $0.duration > 0 }
        let meters = moving.reduce(0) { $0 + $1.distanceMeters }
        guard meters > 0 else { return nil }
        let seconds = moving.reduce(0) { $0 + $1.duration }
        let units = Measurement(value: meters, unit: UnitLength.meters)
            .converted(to: distanceUnit).value
        return seconds / units
    }

    private static func averageDuration(of workouts: [WorkoutRecord]) -> Double {
        guard !workouts.isEmpty else { return 0 }
        return workouts.reduce(0) { $0 + $1.duration } / Double(workouts.count)
    }

    private static func averageEnergy(of workouts: [WorkoutRecord]) -> Double {
        guard !workouts.isEmpty else { return 0 }
        return workouts.reduce(0) { $0 + $1.energyKilocalories } / Double(workouts.count)
    }

    static func paceText(_ secondsPerUnit: Double) -> String {
        let minutes = Int(secondsPerUnit) / 60
        let seconds = Int(secondsPerUnit) % 60
        return String(format: "%d:%02d /%@", minutes, seconds, distanceUnitAbbreviation)
    }
}
