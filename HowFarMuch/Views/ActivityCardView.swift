import SwiftUI

/// One activity's totals, with a bar proportional to the selected metric.
struct ActivityCardView: View {
    let stats: ActivityStats
    let metric: Metric
    /// The largest value of this metric among visible activities (for bar scaling).
    let maxValue: Double

    private var value: Double { metric.value(from: stats) }
    private var fraction: Double { maxValue > 0 ? value / maxValue : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: stats.type.symbolName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(stats.type.tint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(stats.type.tint.opacity(0.18)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(stats.type.displayName)
                        .font(.system(.headline, design: .rounded))
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(metric.formatted(value))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(stats.type.tint)
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [stats.type.tint.opacity(0.7), stats.type.tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, fraction * proxy.size.width))
                }
            }
            .frame(height: 8)
            .animation(.spring(duration: 0.5), value: fraction)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(stats.type.tint.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var subtitle: String {
        var parts: [String] = [Metric.many.formatted(Double(stats.workoutCount))]
        if metric != .long {
            parts.append(Metric.long.formatted(stats.totalDuration))
        }
        if metric != .far, stats.totalDistanceMeters > 0 {
            parts.append(Metric.far.formatted(stats.totalDistanceMeters))
        }
        if metric != .much, stats.totalEnergyKilocalories > 0 {
            parts.append(Metric.much.formatted(stats.totalEnergyKilocalories))
        }
        return parts.joined(separator: " · ")
    }
}
