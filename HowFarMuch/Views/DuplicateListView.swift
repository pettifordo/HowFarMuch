import SwiftUI

/// Shows every recording that duplicate detection ignored, and the recording
/// it was merged into, so the user can audit what the matcher is doing.
struct DuplicateListView: View {
    let pairs: [DuplicatePair]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text("Each card shows the recording that was ignored and the one that counts instead. Adjust the matching in Settings if something here shouldn't be merged.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(pairs) { pair in
                        pairCard(pair)
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Ignored duplicates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func pairCard(_ pair: DuplicatePair) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: pair.removed.type.symbolName)
                    .foregroundStyle(pair.removed.type.tint)
                Text(pair.removed.type.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                Text(pair.removed.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            let crossType = pair.removed.type != pair.kept.type
            recordRow(
                label: "Ignored",
                labelColor: .red,
                record: pair.removed,
                showType: crossType
            )
            recordRow(
                label: "Kept",
                labelColor: .green,
                record: pair.kept,
                showType: crossType
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }

    private func recordRow(label: String, labelColor: Color, record: WorkoutRecord, showType: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(labelColor)
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    showType
                        ? "\(record.sourceName ?? "Unknown source") · \(record.type.displayName)"
                        : (record.sourceName ?? "Unknown source")
                )
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                Text(statsLine(for: record))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(labelColor.opacity(0.08))
        )
    }

    private func statsLine(for record: WorkoutRecord) -> String {
        var parts = [
            record.start.formatted(date: .omitted, time: .shortened),
            Metric.long.formatted(record.duration),
        ]
        if record.distanceMeters > 0 {
            parts.append(Metric.far.formatted(record.distanceMeters))
        }
        if record.energyKilocalories > 0 {
            parts.append(Metric.much.formatted(record.energyKilocalories))
        }
        if let heartRate = record.averageHeartRate {
            parts.append("\(Int(heartRate.rounded())) bpm")
        }
        return parts.joined(separator: " · ")
    }
}
