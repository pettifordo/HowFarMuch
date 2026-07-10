import Foundation

// MARK: - Distance unit preference

enum DistanceUnitPreference: String, CaseIterable, Identifiable {
    case automatic
    case kilometers
    case miles

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: return "Auto"
        case .kilometers: return "km"
        case .miles: return "mi"
        }
    }
}

// MARK: - UserDefaults-backed settings

enum AppSettings {
    static let distanceUnitKey = "distanceUnit"
    static let detectDuplicatesKey = "detectDuplicates"
    static let crossAppDuplicatesKey = "crossAppDuplicates"
    static let overlapThresholdKey = "duplicateOverlapThreshold"
    static let excludeShortWorkoutsKey = "excludeShortWorkouts"
    static let excludedActivitiesKey = "excludedActivities"

    /// Workouts shorter than this are hidden when `excludeShortWorkouts` is on.
    static let shortWorkoutThreshold: TimeInterval = 60

    private static var defaults: UserDefaults { .standard }

    static var distanceUnitPreference: DistanceUnitPreference {
        get {
            DistanceUnitPreference(rawValue: defaults.string(forKey: distanceUnitKey) ?? "")
                ?? .automatic
        }
        set { defaults.set(newValue.rawValue, forKey: distanceUnitKey) }
    }

    /// The unit "How Far" values are shown in, after resolving `automatic` to the region default.
    static var resolvedDistanceUnit: UnitLength {
        switch distanceUnitPreference {
        case .automatic:
            return Locale.current.measurementSystem == .metric ? .kilometers : .miles
        case .kilometers:
            return .kilometers
        case .miles:
            return .miles
        }
    }

    static var distanceUnitAbbreviation: String {
        resolvedDistanceUnit == .kilometers ? "km" : "mi"
    }

    static var detectDuplicates: Bool {
        get { defaults.bool(forKey: detectDuplicatesKey) }
        set { defaults.set(newValue, forKey: detectDuplicatesKey) }
    }

    /// Also treat time-overlapping workouts from different apps (possibly with
    /// different types or distances) as duplicates.
    static var crossAppDuplicates: Bool {
        get { defaults.bool(forKey: crossAppDuplicatesKey) }
        set { defaults.set(newValue, forKey: crossAppDuplicatesKey) }
    }

    /// Fraction of the shorter workout that must overlap in time for the
    /// cross-app matcher to call two workouts the same session (0.1–0.9).
    /// Lower is more aggressive.
    static var overlapThreshold: Double {
        get {
            let stored = defaults.double(forKey: overlapThresholdKey)
            return stored == 0 ? 0.5 : min(max(stored, 0.1), 0.9)
        }
        set { defaults.set(newValue, forKey: overlapThresholdKey) }
    }

    static var excludeShortWorkouts: Bool {
        get { defaults.bool(forKey: excludeShortWorkoutsKey) }
        set { defaults.set(newValue, forKey: excludeShortWorkoutsKey) }
    }

    /// Workout types hidden everywhere in the app (raw HKWorkoutActivityType values).
    static var excludedActivityIDs: Set<UInt> {
        get {
            Set(
                (defaults.string(forKey: excludedActivitiesKey) ?? "")
                    .split(separator: ",")
                    .compactMap { UInt($0) }
            )
        }
        set {
            defaults.set(
                newValue.map(String.init).sorted().joined(separator: ","),
                forKey: excludedActivitiesKey
            )
        }
    }
}
