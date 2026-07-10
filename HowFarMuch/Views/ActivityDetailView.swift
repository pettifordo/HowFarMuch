import SwiftUI
import Charts
import HealthKit

// MARK: - Drill-down: workout history + trend analysis for one activity

struct ActivityDetailView: View {
    let type: HKWorkoutActivityType
    let workouts: [WorkoutRecord]
    let periodPhrase: String

    @State private var mode: Mode = .history
    @State private var grouping: HistoryGrouping
    @State private var chartMetric: ChartMetric = .duration

    enum Mode: String, CaseIterable, Identifiable {
        case history = "History"
        case analyse = "Analyse"
        var id: String { rawValue }
    }

    init(type: HKWorkoutActivityType, workouts: [WorkoutRecord], periodPhrase: String, defaultGrouping: HistoryGrouping) {
        self.type = type
        self.workouts = workouts
        self.periodPhrase = periodPhrase
        _grouping = State(initialValue: defaultGrouping)
        let hasDistance = workouts.contains { $0.distanceMeters > 0 }
        _chartMetric = State(initialValue: hasDistance ? .pace : .duration)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    modePicker
                    if mode == .history {
                        groupingPicker
                        historyGroups
                    } else {
                        analyseSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Header totals

    private var totals: ActivityStats {
        ActivityStats.aggregate(workouts).first
            ?? ActivityStats(type: type)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: type.symbolName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(type.tint)
            Text(totalsLine(for: totals))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text(periodPhrase)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(type.tint.opacity(0.1))
        )
    }

    private func totalsLine(for stats: ActivityStats) -> String {
        var parts = [
            Metric.many.formatted(Double(stats.workoutCount)),
            Metric.long.formatted(stats.totalDuration),
        ]
        if stats.totalDistanceMeters > 0 {
            parts.append(Metric.far.formatted(stats.totalDistanceMeters))
        }
        if stats.totalEnergyKilocalories > 0 {
            parts.append(Metric.much.formatted(stats.totalEnergyKilocalories))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Mode & grouping pickers

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases) { candidate in
                Button {
                    withAnimation(.spring(duration: 0.35)) { mode = candidate }
                } label: {
                    Label(
                        candidate.rawValue,
                        systemImage: candidate == .history ? "list.bullet" : "chart.line.uptrend.xyaxis"
                    )
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(mode == candidate ? type.tint.opacity(0.3) : .white.opacity(0.07))
                    )
                    .overlay(
                        Capsule().strokeBorder(mode == candidate ? type.tint : .clear, lineWidth: 1)
                    )
                    .foregroundStyle(mode == candidate ? type.tint : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var groupingPicker: some View {
        Picker("Group", selection: $grouping) {
            ForEach(HistoryGrouping.allCases) { candidate in
                Text(candidate.rawValue).tag(candidate)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - History

    private var groups: [(key: Date, workouts: [WorkoutRecord])] {
        Dictionary(grouping: workouts) { grouping.key(for: $0.start) }
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value.sorted { $0.start > $1.start }) }
    }

    private var historyGroups: some View {
        LazyVStack(spacing: 16) {
            ForEach(groups, id: \.key) { group in
                VStack(alignment: .leading, spacing: 8) {
                    let groupTotals = ActivityStats.aggregate(group.workouts).first
                        ?? ActivityStats(type: type)
                    Text(grouping.title(for: group.key))
                        .font(.system(.headline, design: .rounded))
                    Text(totalsLine(for: groupTotals))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(type.tint)
                    VStack(spacing: 1) {
                        ForEach(group.workouts) { workout in
                            workoutRow(workout)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func workoutRow(_ workout: WorkoutRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(workout.start.formatted(date: .omitted, time: .shortened))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 14) {
                statColumn(Metric.long.formatted(workout.duration), caption: "time")
                if workout.distanceMeters > 0 {
                    statColumn(Metric.far.formatted(workout.distanceMeters), caption: "dist")
                }
                if workout.energyKilocalories > 0 {
                    statColumn("\(Int(workout.energyKilocalories.rounded()))", caption: "kcal")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05))
    }

    private func statColumn(_ value: String, caption: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text(caption)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Analyse

    private var findings: [TrendFinding] {
        TrendAnalyzer.findings(for: workouts)
    }

    @ViewBuilder
    private var analyseSection: some View {
        if findings.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundStyle(type.tint)
                Text("Not enough workouts yet")
                    .font(.system(.headline, design: .rounded))
                Text("Trends need at least \(TrendAnalyzer.minimumWorkouts) \(type.displayName.lowercased()) workouts in this period. Try a longer period.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            .padding(.horizontal, 20)
        } else {
            VStack(spacing: 12) {
                Text("Comparing the first half of these workouts with the most recent half")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(findings) { finding in
                    trendCard(finding)
                }
                chartPanel
            }
        }
    }

    private func trendCard(_ finding: TrendFinding) -> some View {
        let color: Color = finding.isNeutral ? .secondary : (finding.isGood ? .green : .red)
        return HStack(spacing: 12) {
            Image(systemName: finding.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(type.tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(type.tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.verdict)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(color)
                Text("\(finding.earlierText)  →  \(finding.laterText)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 3) {
                if !finding.isNeutral {
                    Image(systemName: finding.percentChange > 0 ? "arrow.up.right" : "arrow.down.right")
                }
                Text(finding.percentChange.formatted(.percent.precision(.fractionLength(0...1))))
            }
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(color)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }

    // MARK: - Chart

    private struct ChartPoint: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
    }

    private var chartPoints: [ChartPoint] {
        workouts
            .sorted { $0.start < $1.start }
            .compactMap { workout in
                chartMetric.value(for: workout).map {
                    ChartPoint(id: workout.id, date: workout.start, value: $0)
                }
            }
    }

    @ViewBuilder
    private var chartPanel: some View {
        VStack(spacing: 12) {
            Picker("Metric", selection: $chartMetric) {
                ForEach(ChartMetric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            let points = chartPoints
            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(chartMetric.rawValue, point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(type.tint.opacity(0.7))
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(chartMetric.rawValue, point.value)
                    )
                    .foregroundStyle(type.tint)
                    .symbolSize(28)
                }
                .chartYAxisLabel(chartMetric.axisLabel)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
                if chartMetric == .pace {
                    Text("Lower is faster")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No \(chartMetric.rawValue.lowercased()) data for these workouts")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 30)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }
}

// MARK: - Chartable per-workout metrics

enum ChartMetric: String, CaseIterable, Identifiable {
    case pace = "Pace"
    case duration = "Time"
    case energy = "Calories"

    var id: String { rawValue }

    var axisLabel: String {
        switch self {
        case .pace: return "min/\(TrendAnalyzer.distanceUnitAbbreviation)"
        case .duration: return "minutes"
        case .energy: return "kcal"
        }
    }

    func value(for workout: WorkoutRecord) -> Double? {
        switch self {
        case .pace:
            guard workout.distanceMeters > 0, workout.duration > 0 else { return nil }
            let units = Measurement(value: workout.distanceMeters, unit: UnitLength.meters)
                .converted(to: TrendAnalyzer.distanceUnit).value
            guard units > 0 else { return nil }
            return workout.duration / units / 60
        case .duration:
            return workout.duration / 60
        case .energy:
            return workout.energyKilocalories > 0 ? workout.energyKilocalories : nil
        }
    }
}
