import SwiftUI
import HealthKit

struct SettingsView: View {
    /// Activity types to offer exclusion toggles for (from the fetched data).
    let availableTypes: [HKWorkoutActivityType]
    /// Raw workouts for the current period, pre-exclusion and pre-dedupe,
    /// so the duplicate count can update live as settings change.
    let rawWorkouts: [WorkoutRecord]
    /// e.g. "in the last 7 days" — the duplicate count is scoped to this.
    let periodPhrase: String

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.distanceUnitKey) private var distanceUnitRaw
        = DistanceUnitPreference.automatic.rawValue
    @AppStorage(AppSettings.detectDuplicatesKey) private var detectDuplicates = false
    @AppStorage(AppSettings.crossAppDuplicatesKey) private var crossAppDuplicates = false
    @AppStorage(AppSettings.overlapThresholdKey) private var overlapThreshold = 0.5
    @AppStorage(AppSettings.excludeShortWorkoutsKey) private var excludeShortWorkouts = false
    @AppStorage(AppSettings.compactValuesKey) private var compactValues = false
    @AppStorage(AppSettings.shareTodayKey) private var shareToday = true
    @AppStorage(AppSettings.shareHeartRateKey) private var shareHeartRate = false
    @AppStorage(AppSettings.displayNameKey) private var displayName = ""
    @AppStorage(AppSettings.displayEmojiKey) private var displayEmoji = ""
    @State private var excluded = AppSettings.excludedActivityIDs
    @State private var showDuplicateList = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        section("Distance unit") { unitContent }
                        section("Large values") { compactContent }
                        section("Duplicate workouts") { duplicateContent }
                        section("Short workouts") { shortWorkoutContent }
                        section("Workout types") { excludeContent }
                        section("Sharing with friends") { sharingContent }
                        section("Help & about") { aboutContent }
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showDuplicateList) {
                DuplicateListView(pairs: duplicatePairs)
            }
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

    // MARK: - Compact values

    @ViewBuilder
    private var compactContent: some View {
        Toggle("Compact large values", isOn: $compactValues)
            .font(.system(.body, design: .rounded, weight: .medium))
            .tint(.cyan)
        caption("Shows big numbers briefly — 69,319 kcal becomes 69.3K kcal — and long totals as days, weeks, months or years (128h 23m becomes 5d 8h). Applies in the app and in widgets.")
    }

    // MARK: - Duplicates

    /// Recomputed live as any toggle or the slider changes.
    private var duplicatePairs: [DuplicatePair] {
        guard detectDuplicates else { return [] }
        var filtered = rawWorkouts.filter { !excluded.contains($0.type.rawValue) }
        if excludeShortWorkouts {
            filtered = filtered.filter { $0.duration >= AppSettings.shortWorkoutThreshold }
        }
        return DuplicateDetector.deduplicate(
            filtered,
            acrossApps: crossAppDuplicates,
            overlapThreshold: overlapThreshold
        ).removed
    }

    @ViewBuilder
    private var duplicateContent: some View {
        Toggle("Ignore duplicates", isOn: $detectDuplicates)
            .font(.system(.body, design: .rounded, weight: .medium))
            .tint(.cyan)
        caption("Workouts of the same type that start within 10 minutes of each other with similar duration and distance count once — usually iPhone and Apple Watch both recording the same session.")
        if detectDuplicates {
            duplicateCountRow
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
        }
    }

    @ViewBuilder
    private var duplicateCountRow: some View {
        let count = duplicatePairs.count
        if count == 0 {
            Label("No duplicates found \(periodPhrase)", systemImage: "checkmark.circle")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
        } else {
            Button {
                showDuplicateList = true
            } label: {
                HStack {
                    Label(
                        count == 1
                            ? "1 duplicate found \(periodPhrase)"
                            : "\(count) duplicates found \(periodPhrase)",
                        systemImage: "rectangle.on.rectangle.slash"
                    )
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .contentTransition(.numericText())
                    Spacer()
                    Text("View")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.cyan)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.cyan.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
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

    // MARK: - Sharing with friends

    @ViewBuilder
    private var sharingContent: some View {
        HStack {
            Text("Your name")
                .font(.system(.body, design: .rounded, weight: .medium))
            Spacer()
            TextField("Me", text: $displayName)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .frame(maxWidth: 160)
        }
        Divider().overlay(.white.opacity(0.1))
        HStack {
            Text("Your emoji")
                .font(.system(.body, design: .rounded, weight: .medium))
            Spacer()
            TextField("🏃", text: $displayEmoji)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.plain)
                .frame(maxWidth: 60)
                .onChange(of: displayEmoji) { _, newValue in
                    if newValue.count > 2 {
                        displayEmoji = String(newValue.suffix(2))
                    }
                }
        }
        Divider().overlay(.white.opacity(0.1))
        Toggle("Share today's totals", isOn: $shareToday)
            .font(.system(.body, design: .rounded, weight: .medium))
            .tint(.cyan)
        caption("Turning this off shares weekly totals and up, so friends can't tell whether you're out right now.")
        Toggle("Share average heart rate", isOn: $shareHeartRate)
            .font(.system(.body, design: .rounded, weight: .medium))
            .tint(.cyan)
        caption("Friends only ever see totals — never individual workouts, times or routes. Excluded workout types stay hidden from friends too.")
    }

    // MARK: - Help & about

    @ViewBuilder
    private var aboutContent: some View {
        linkRow(
            title: "Support & FAQ",
            symbol: "questionmark.circle.fill",
            url: "https://pettifordo.github.io/HowFarMuch/support.html"
        )
        Divider().overlay(.white.opacity(0.1))
        linkRow(
            title: "Privacy Policy",
            symbol: "hand.raised.fill",
            url: "https://pettifordo.github.io/HowFarMuch/privacy.html"
        )
        Divider().overlay(.white.opacity(0.1))
        HStack {
            Label {
                Text("Version")
                    .font(.system(.body, design: .rounded, weight: .medium))
            } icon: {
                Image(systemName: "app.badge.checkmark")
                    .foregroundStyle(.cyan)
            }
            Spacer()
            Text(appVersion)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func linkRow(title: String, symbol: String, url: String) -> some View {
        Link(destination: URL(string: url) ?? URL(fileURLWithPath: "/")) {
            HStack {
                Label {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                } icon: {
                    Image(systemName: symbol)
                        .foregroundStyle(.cyan)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
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
    SettingsView(
        availableTypes: [.running, .cycling, .walking],
        rawWorkouts: [],
        periodPhrase: "in the last 7 days"
    )
}
