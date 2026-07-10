import SwiftUI
import HealthKit

struct SettingsView: View {
    /// Activity types to offer exclusion toggles for (from the fetched data).
    let availableTypes: [HKWorkoutActivityType]
    /// Raw workouts for the current period, pre-exclusion and pre-dedupe,
    /// so the duplicate count can update live as settings change.
    let rawWorkouts: [WorkoutRecord]

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.distanceUnitKey) private var distanceUnitRaw
        = DistanceUnitPreference.automatic.rawValue
    @AppStorage(AppSettings.detectDuplicatesKey) private var detectDuplicates = false
    @AppStorage(AppSettings.crossAppDuplicatesKey) private var crossAppDuplicates = false
    @AppStorage(AppSettings.overlapThresholdKey) private var overlapThreshold = 0.5
    @AppStorage(AppSettings.excludeShortWorkoutsKey) private var excludeShortWorkouts = false
    @State private var excluded = AppSettings.excludedActivityIDs

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        section("Distance unit") { unitContent }
                        section("Duplicate workouts") { duplicateContent }
                        section("Short workouts") { shortWorkoutContent }
                        section("Workout types") { excludeContent }
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(.cyan)
                }
            }
        }
    }

    // MARK: - Distance unit

    @ViewBuilder
    private var unitContent: some View {
        Picker("Distance unit", selection: $distanceUnitRaw) {
            ForEach(DistanceUnitPreference.allCases) { preference in
                Text(preference.label).tag(preference.rawValue)
            }
        }
        .pickerStyle(.segmented)
        caption("How Far distances are shown in this unit. Auto follows your region setting.")
    }

    // MARK: - Duplicates

    private var liveDuplicateCount: Int {
        guard detectDuplicates else { return 0 }
        var filtered = rawWorkouts.filter { !excluded.contains($0.type.rawValue) }
        if excludeShortWorkouts {
            filtered = filtered.filter { $0.duration >= AppSettings.shortWorkoutThreshold }
        }
        return DuplicateDetector.deduplicate(
            filtered,
            acrossApps: crossAppDuplicates,
            overlapThreshold: overlapThreshold
        ).removedCount
    }

    @ViewBuilder
    private var duplicateContent: some View {
        Toggle("Ignore duplicates", isOn: $detectDuplicates)
            .font(.system(.body, design: .rounded, weight: .medium))
            .tint(.cyan)
        caption("Workouts of the same type that start within 10 minutes of each other with similar duration and distance count once — usually iPhone and Apple Watch both recording the same session.")
        if detectDuplicates {
            Divider().overlay(.white.opacity(0.1))
            Toggle("Also match across apps", isOn: $crossAppDuplicates)
                .font(.system(.body, design: .rounded, weight: .medium))
                .tint(.cyan)
            caption("Casts a wider net: any two workouts that overlap in time count as one session, even when the type, distance or app differs — e.g. a third-party tracker on the phone plus an Outdoor Run on the watch. The recording with the most data (heart rate, then distance) is kept.")
            if crossAppDuplicates {
                HStack {
                    Text("Overlap required")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                    Spacer()
                    Text("\(Int((overlapThreshold * 100).rounded()))%")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.cyan)
                        .contentTransition(.numericText())
                }
                Slider(value: $overlapThreshold, in: 0.1...0.9, step: 0.05)
                    .tint(.cyan)
                caption("How much of the shorter workout must overlap in time to count as the same session. Lower is more aggressive and catches more; higher is safer if you sometimes do back-to-back workouts.")
            }
            Label(
                liveDuplicateCount == 1
                    ? "1 workout ignored as a duplicate"
                    : "\(liveDuplicateCount) workouts ignored as duplicates",
                systemImage: "rectangle.on.rectangle.slash"
            )
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(.cyan)
        }
    }

    // MARK: - Short workouts

    @ViewBuilder
    private var shortWorkoutContent: some View {
        Toggle("Exclude short workouts", isOn: $excludeShortWorkouts)
            .font(.system(.body, design: .rounded, weight: .medium))
            .tint(.cyan)
        caption("Hides workouts shorter than a minute — accidental starts and test recordings.")
    }

    // MARK: - Excluded types

    @ViewBuilder
    private var excludeContent: some View {
        if availableTypes.isEmpty {
            caption("Workout types will appear here once you have some workouts.")
        } else {
            ForEach(availableTypes, id: \.rawValue) { type in
                Toggle(isOn: inclusionBinding(for: type)) {
                    Label {
                        Text(type.displayName)
                            .font(.system(.body, design: .rounded, weight: .medium))
                    } icon: {
                        Image(systemName: type.symbolName)
                            .foregroundStyle(type.tint)
                    }
                }
                .tint(.cyan)
            }
            caption("Switch a type off to hide those workouts everywhere in the app.")
        }
    }

    private func inclusionBinding(for type: HKWorkoutActivityType) -> Binding<Bool> {
        Binding(
            get: { !excluded.contains(type.rawValue) },
            set: { include in
                if include {
                    excluded.remove(type.rawValue)
                } else {
                    excluded.insert(type.rawValue)
                }
                AppSettings.excludedActivityIDs = excluded
            }
        )
    }

    // MARK: - Section chrome

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.headline, design: .rounded))
            VStack(alignment: .leading, spacing: 12, content: content)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.06))
                )
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    SettingsView(availableTypes: [.running, .cycling, .walking], rawWorkouts: [])
}
