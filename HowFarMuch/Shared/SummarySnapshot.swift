import Foundation

/// The app's current summary — period, metric, filters, formatted totals —
/// written to the App Group whenever the selection changes, and read by the
/// widgets. Strings are pre-formatted app-side so unit and compact-value
/// settings flow through automatically.
struct SummarySnapshot: Codable {
    static let appGroupID = "group.com.owenpettiford.HowFarMuch"
    static let storageKey = "summarySnapshot"

    /// Selected metric, e.g. "How Far".
    var heroTitle: String
    /// Formatted value of the selected metric, e.g. "58 mi".
    var heroValue: String
    /// e.g. "in the last 7 days".
    var periodPhrase: String
    /// e.g. "All activities" or "Running, Cycling".
    var activities: String
    var far: String?
    var long: String
    var much: String?
    var many: String
    /// e.g. "132 bpm", time-weighted across the filtered workouts.
    var avgHeartRate: String?
    var isDemo: Bool
    var updated: Date

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroupID)?.set(data, forKey: Self.storageKey)
    }

    static func load() -> SummarySnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(SummarySnapshot.self, from: data)
    }

    static let placeholder = SummarySnapshot(
        heroTitle: "How Far",
        heroValue: "58 mi",
        periodPhrase: "in the last 7 days",
        activities: "All activities",
        far: "58 mi",
        long: "8h 45m",
        much: "4,969 kcal",
        many: "12 workouts",
        avgHeartRate: "132 bpm",
        isDemo: false,
        updated: .now
    )
}
