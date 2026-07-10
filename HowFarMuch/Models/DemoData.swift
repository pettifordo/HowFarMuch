import Foundation
import HealthKit

/// Sample workouts so the UI is visible in the simulator, where Health has no data.
/// Generated with a mild improvement trend so the Analyse screen shows movement.
enum DemoData {
    static func records(in period: Period) -> [WorkoutRecord] {
        let start = period.startDate
        return all.filter { $0.start >= start }
    }

    private static let all: [WorkoutRecord] = generate()

    private struct Config {
        let type: HKWorkoutActivityType
        let perWeek: Int
        let baseMinutes: Double
        let minutesGain: Double
        let speedKmh: Double
        let speedGainKmh: Double
        let kcalPerMinute: Double
        let baseHeartRate: Double
    }

    private static func generate() -> [WorkoutRecord] {
        // Deterministic pseudo-random so the demo looks the same every launch.
        var state: UInt64 = 42
        func random(_ range: ClosedRange<Double>) -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(state >> 11) / Double(1 << 53)
            return range.lowerBound + unit * (range.upperBound - range.lowerBound)
        }

        let configs: [Config] = [
            Config(type: .running, perWeek: 3, baseMinutes: 40, minutesGain: 12,
                   speedKmh: 9.2, speedGainKmh: 1.4, kcalPerMinute: 11, baseHeartRate: 156),
            Config(type: .cycling, perWeek: 2, baseMinutes: 65, minutesGain: 15,
                   speedKmh: 19, speedGainKmh: 2.5, kcalPerMinute: 9, baseHeartRate: 141),
            Config(type: .walking, perWeek: 4, baseMinutes: 35, minutesGain: 3,
                   speedKmh: 5.2, speedGainKmh: 0.2, kcalPerMinute: 5, baseHeartRate: 106),
            Config(type: .swimming, perWeek: 1, baseMinutes: 40, minutesGain: 6,
                   speedKmh: 2.3, speedGainKmh: 0.2, kcalPerMinute: 10.5, baseHeartRate: 138),
            Config(type: .traditionalStrengthTraining, perWeek: 2, baseMinutes: 45, minutesGain: 10,
                   speedKmh: 0, speedGainKmh: 0, kcalPerMinute: 7, baseHeartRate: 118),
            Config(type: .yoga, perWeek: 1, baseMinutes: 30, minutesGain: 5,
                   speedKmh: 0, speedGainKmh: 0, kcalPerMinute: 4, baseHeartRate: 92),
        ]

        let calendar = Calendar.current
        let now = Date()
        let totalWeeks = 62
        var records: [WorkoutRecord] = []

        for weekOffset in 0..<totalWeeks {
            // progress: 0 at the oldest week → 1 this week (drives the improvement trend)
            let progress = 1 - Double(weekOffset) / Double(totalWeeks - 1)
            guard let weekAnchor = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now) else {
                continue
            }
            for config in configs {
                for occurrence in 0..<config.perWeek {
                    let daySpread = occurrence * (7 / max(1, config.perWeek))
                    guard let day = calendar.date(byAdding: .day, value: -daySpread, to: weekAnchor),
                          let start = calendar.date(
                            bySettingHour: Int(random(7...19)), minute: Int(random(0...59)),
                            second: 0, of: day
                          ),
                          start <= now else { continue }

                    let minutes = (config.baseMinutes + config.minutesGain * progress) * random(0.85...1.15)
                    let speed = (config.speedKmh + config.speedGainKmh * progress) * random(0.93...1.07)
                    records.append(WorkoutRecord(
                        id: UUID(),
                        type: config.type,
                        start: start,
                        duration: minutes * 60,
                        distanceMeters: speed * minutes / 60 * 1000,
                        energyKilocalories: config.kcalPerMinute * minutes * random(0.9...1.1),
                        // A little fitter over time: same effort at a lower heart rate
                        averageHeartRate: config.baseHeartRate - 5 * progress + random(-4...4)
                    ))
                }
            }
        }
        let base = records

        // Tight phone+watch double-recordings (caught by basic duplicate detection).
        for (index, record) in base.enumerated() where index % 9 == 0 && record.distanceMeters > 0 {
            records.append(WorkoutRecord(
                id: UUID(),
                type: record.type,
                start: record.start.addingTimeInterval(90),
                duration: record.duration * 0.97,
                distanceMeters: record.distanceMeters * 0.99,
                energyKilocalories: record.energyKilocalories * 1.02,
                averageHeartRate: nil
            ))
        }

        // Sloppier third-party-app recordings of the same session: started well
        // into the workout and ran past its end, so they overlap ~73% of the
        // shorter recording — only the cross-app matcher catches these, and only
        // while the overlap threshold is below that.
        for (index, record) in base.enumerated()
        where index % 13 == 5 && record.distanceMeters > 0 && record.duration > 20 * 60 {
            records.append(WorkoutRecord(
                id: UUID(),
                type: record.type,
                start: record.start.addingTimeInterval(record.duration * 0.45),
                duration: record.duration * 0.75,
                distanceMeters: record.distanceMeters * 0.7,
                energyKilocalories: record.energyKilocalories * 0.75,
                averageHeartRate: nil
            ))
        }

        // Accidental starts under a minute.
        for dayOffset in [2, 9, 23] {
            if let day = calendar.date(byAdding: .day, value: -dayOffset, to: now),
               let start = calendar.date(bySettingHour: 12, minute: 3, second: 0, of: day) {
                records.append(WorkoutRecord(
                    id: UUID(),
                    type: .walking,
                    start: start,
                    duration: 35,
                    distanceMeters: 25,
                    energyKilocalories: 2,
                    averageHeartRate: nil
                ))
            }
        }

        return records.sorted { $0.start > $1.start }
    }
}
