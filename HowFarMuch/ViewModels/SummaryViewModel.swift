import Foundation
import HealthKit
import Observation
import WidgetKit

@MainActor
@Observable
final class SummaryViewModel {
    var period: Period = .week {
        didSet { Task { await load() } }
    }
    var metric: Metric = .far {
        didSet { publishSnapshot() }
    }
    var hiddenActivityIDs: Set<UInt> = [] {
        didSet { publishSnapshot() }
    }
    /// Everything fetched for the period, before settings exclusions and dedupe.
    var fetchedWorkouts: [WorkoutRecord] = []
    var allWorkouts: [WorkoutRecord] = []
    var allStats: [ActivityStats] = []
    /// Activity types in the fetched data plus any currently excluded, for the settings page.
    var availableTypes: [HKWorkoutActivityType] = []
    var duplicatesIgnored = 0
    var isLoading = false
    var isDemoData = false
    var errorMessage: String?

    private let healthKit = HealthKitService()
    private var hasRequestedAuthorization = false

    /// Stats after the user's activity filters are applied.
    var visibleStats: [ActivityStats] {
        allStats.filter { !hiddenActivityIDs.contains($0.id) }
    }

    /// Individual workouts after the user's activity filters are applied.
    var visibleWorkouts: [WorkoutRecord] {
        allWorkouts.filter { !hiddenActivityIDs.contains($0.type.rawValue) }
    }

    /// Current filtered totals, for both share formats.
    var shareCardData: ShareCardData {
        let stats = visibleStats
        let distance = stats.reduce(0) { $0 + $1.totalDistanceMeters }
        let duration = stats.reduce(0) { $0 + $1.totalDuration }
        let energy = stats.reduce(0) { $0 + $1.totalEnergyKilocalories }
        let count = stats.reduce(0) { $0 + $1.workoutCount }
        return ShareCardData(
            periodPhrase: period.phrase,
            activities: hiddenActivityIDs.isEmpty
                ? "All activities"
                : stats.map(\.type.displayName).joined(separator: ", "),
            farText: distance > 0 ? Metric.far.formatted(distance) : nil,
            longText: Metric.long.formatted(duration),
            muchText: energy > 0 ? Metric.much.formatted(energy) : nil,
            manyText: Metric.many.formatted(Double(count)),
            isDemo: isDemoData
        )
    }

    /// Text version of the summary, for the share sheet.
    var shareSummary: String {
        let data = shareCardData
        var lines = [
            "My workouts \(data.periodPhrase) — How Far/Much",
            "🏅 \(data.activities)",
        ]
        if let far = data.farText {
            lines.append("📏 How Far: \(far)")
        }
        lines.append("⏱️ How Long: \(data.longText)")
        if let much = data.muchText {
            lines.append("🔥 How Much: \(much)")
        }
        lines.append("#️⃣ How Many: \(data.manyText)")
        if data.isDemo {
            lines.append("(demo data)")
        }
        return lines.joined(separator: "\n")
    }

    /// Grand total of the selected metric across visible activities.
    var heroValue: Double {
        visibleStats.reduce(0) { $0 + metric.value(from: $1) }
    }

    /// Time-weighted average heart rate across visible workouts that recorded one.
    var averageHeartRate: Double? {
        let withHeartRate = visibleWorkouts.filter { $0.averageHeartRate != nil && $0.duration > 0 }
        let totalTime = withHeartRate.reduce(0) { $0 + $1.duration }
        guard totalTime > 0 else { return nil }
        let weighted = withHeartRate.reduce(0) { $0 + ($1.averageHeartRate ?? 0) * $1.duration }
        return weighted / totalTime
    }

    /// Largest per-activity value of the selected metric, for proportional bars.
    var maxMetricValue: Double {
        visibleStats.map { metric.value(from: $0) }.max() ?? 0
    }

    func workouts(for type: HKWorkoutActivityType) -> [WorkoutRecord] {
        allWorkouts.filter { $0.type == type }
    }

    func toggleFilter(for stats: ActivityStats) {
        if hiddenActivityIDs.contains(stats.id) {
            hiddenActivityIDs.remove(stats.id)
        } else {
            hiddenActivityIDs.insert(stats.id)
        }
    }

    func showAllActivities() {
        hiddenActivityIDs.removeAll()
    }

    func load() async {
        errorMessage = nil
        #if targetEnvironment(simulator)
        // The simulator has no workouts to read, so show sample data
        // immediately instead of a permission sheet over an empty screen.
        loadDemoDataIfSimulator(reason: nil)
        #else
        guard healthKit.isAvailable else {
            loadDemoDataIfSimulator(reason: "Health data isn't available on this device.")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            if !hasRequestedAuthorization {
                try await healthKit.requestAuthorization()
                hasRequestedAuthorization = true
            }
            fetchedWorkouts = try await healthKit.fetchWorkouts(from: period.startDate)
            allWorkouts = applySettings(to: fetchedWorkouts)
            allStats = ActivityStats.aggregate(allWorkouts)
            isDemoData = false
        } catch {
            loadDemoDataIfSimulator(reason: error.localizedDescription)
        }
        #endif
        publishSnapshot()
    }

    /// Writes the current summary to the App Group so the widgets can show it.
    private func publishSnapshot() {
        let data = shareCardData
        SummarySnapshot(
            heroTitle: metric.rawValue,
            heroValue: metric.formatted(heroValue),
            periodPhrase: period.phrase,
            activities: data.activities,
            far: data.farText,
            long: data.longText,
            much: data.muchText,
            many: data.manyText,
            avgHeartRate: averageHeartRate.map { "\(Int($0.rounded())) bpm" },
            isDemo: isDemoData,
            updated: .now
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The simulator has no real workouts, so fall back to sample data there
    /// (clearly badged in the UI). On a real device we surface the empty state instead.
    private func loadDemoDataIfSimulator(reason: String?) {
        #if targetEnvironment(simulator)
        fetchedWorkouts = DemoData.records(in: period)
        allWorkouts = applySettings(to: fetchedWorkouts)
        allStats = ActivityStats.aggregate(allWorkouts)
        isDemoData = true
        #else
        errorMessage = reason
        #endif
    }

    /// Applies the settings-page rules: excluded activity types, then duplicate removal.
    private func applySettings(to records: [WorkoutRecord]) -> [WorkoutRecord] {
        let excluded = AppSettings.excludedActivityIDs

        var seen = Set<UInt>()
        var types: [HKWorkoutActivityType] = []
        for record in records where seen.insert(record.type.rawValue).inserted {
            types.append(record.type)
        }
        for id in excluded where seen.insert(id).inserted {
            if let type = HKWorkoutActivityType(rawValue: id) {
                types.append(type)
            }
        }
        availableTypes = types.sorted { $0.displayName < $1.displayName }

        var result = records.filter { !excluded.contains($0.type.rawValue) }
        if AppSettings.excludeShortWorkouts {
            result = result.filter { $0.duration >= AppSettings.shortWorkoutThreshold }
        }
        if AppSettings.detectDuplicates {
            let deduplicated = DuplicateDetector.deduplicate(
                result,
                acrossApps: AppSettings.crossAppDuplicates,
                overlapThreshold: AppSettings.overlapThreshold
            )
            result = deduplicated.kept
            duplicatesIgnored = deduplicated.removed.count
        } else {
            duplicatesIgnored = 0
        }
        return result
    }
}
