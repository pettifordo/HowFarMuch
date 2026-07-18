import Foundation

/// The settings-page rules (excluded types, short workouts, duplicates),
/// applied identically wherever workouts are consumed — the dashboard and
/// the published friends feed must agree.
enum WorkoutFilters {
    static func apply(_ records: [WorkoutRecord]) -> (kept: [WorkoutRecord], duplicatesIgnored: Int) {
        let excluded = AppSettings.excludedActivityIDs
        var result = records.filter { !excluded.contains($0.type.rawValue) }
        if AppSettings.excludeShortWorkouts {
            result = result.filter { $0.duration >= AppSettings.shortWorkoutThreshold }
        }
        var duplicatesIgnored = 0
        if AppSettings.detectDuplicates {
            let deduplicated = DuplicateDetector.deduplicate(
                result,
                acrossApps: AppSettings.crossAppDuplicates,
                overlapThreshold: AppSettings.overlapThreshold
            )
            result = deduplicated.kept
            duplicatesIgnored = deduplicated.removed.count
        }
        return (result, duplicatesIgnored)
    }
}
