import Foundation

/// Finds workouts that were recorded twice.
///
/// Two levels of matching:
/// - **Same-app style** (always on when dedupe is enabled): same activity type,
///   starts within 10 minutes, similar duration and distance — typically iPhone
///   and Apple Watch both logging the same session.
/// - **Cross-app** (`acrossApps: true`): additionally matches any two workouts
///   that overlap in time by at least half of the shorter one, regardless of
///   activity type or distance. You can't do two workouts at once, so heavy
///   overlap means one session recorded by two apps — e.g. a third-party
///   tracker on the phone plus an Outdoor Run on the watch.
enum DuplicateDetector {
    static func deduplicate(
        _ records: [WorkoutRecord],
        acrossApps: Bool = false,
        overlapThreshold: Double = 0.5
    ) -> (kept: [WorkoutRecord], removedCount: Int) {
        let sorted = records.sorted { $0.start < $1.start }
        var kept: [WorkoutRecord] = []
        var removed = 0

        for record in sorted {
            var matchIndex: Int?
            // Scan recent kept records; nothing further back than 12h can overlap.
            for index in stride(from: kept.count - 1, through: 0, by: -1) {
                if record.start.timeIntervalSince(kept[index].start) > 12 * 3600 { break }
                if isDuplicate(kept[index], record, acrossApps: acrossApps, overlapThreshold: overlapThreshold) {
                    matchIndex = index
                    break
                }
            }
            if let matchIndex {
                removed += 1
                // Keep whichever copy carries more data.
                if richness(record) > richness(kept[matchIndex]) {
                    kept[matchIndex] = record
                }
            } else {
                kept.append(record)
            }
        }

        return (kept.sorted { $0.start > $1.start }, removed)
    }

    private static func isDuplicate(
        _ a: WorkoutRecord,
        _ b: WorkoutRecord,
        acrossApps: Bool,
        overlapThreshold: Double
    ) -> Bool {
        if sameTypeMatch(a, b) { return true }
        if acrossApps { return overlapMatch(a, b, threshold: overlapThreshold) }
        return false
    }

    private static func sameTypeMatch(_ a: WorkoutRecord, _ b: WorkoutRecord) -> Bool {
        guard a.type == b.type else { return false }
        guard abs(a.start.timeIntervalSince(b.start)) <= 10 * 60 else { return false }
        guard similar(a.duration, b.duration, tolerance: 0.15, absoluteFloor: 180) else { return false }
        // Similar distance — or neither really covered any.
        if a.distanceMeters < 100 && b.distanceMeters < 100 { return true }
        return similar(a.distanceMeters, b.distanceMeters, tolerance: 0.15, absoluteFloor: 200)
    }

    private static func overlapMatch(_ a: WorkoutRecord, _ b: WorkoutRecord, threshold: Double) -> Bool {
        guard a.duration > 0, b.duration > 0 else { return false }
        let overlap = min(a.start.addingTimeInterval(a.duration), b.start.addingTimeInterval(b.duration))
            .timeIntervalSince(max(a.start, b.start))
        return overlap >= threshold * min(a.duration, b.duration)
    }

    private static func similar(_ x: Double, _ y: Double, tolerance: Double, absoluteFloor: Double) -> Bool {
        let difference = abs(x - y)
        if difference <= absoluteFloor { return true }
        let base = max(x, y)
        return base > 0 && difference / base <= tolerance
    }

    /// Prefer the copy with heart rate (usually the Watch), then distance, then calories.
    private static func richness(_ record: WorkoutRecord) -> Int {
        (record.averageHeartRate != nil ? 4 : 0)
            + (record.distanceMeters > 0 ? 2 : 0)
            + (record.energyKilocalories > 0 ? 1 : 0)
    }
}
