import WidgetKit
import SwiftUI

// MARK: - Bundle

@main
struct HowFarMuchWidgetBundle: WidgetBundle {
    var body: some Widget {
        SummaryWidget()
    }
}

struct SummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HowFarMuchSummary", provider: SummaryProvider()) { entry in
            SummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("Workout totals")
        .description("Your totals for the period, metric and activities selected in the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline

struct SummaryEntry: TimelineEntry {
    let date: Date
    let snapshot: SummarySnapshot
}

struct SummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        completion(SummaryEntry(date: .now, snapshot: SummarySnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        // Data only changes when the app writes a new snapshot; the app
        // triggers a reload after every write.
        let entry = SummaryEntry(date: .now, snapshot: SummarySnapshot.load() ?? .placeholder)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Views

struct SummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SummaryEntry

    private var snapshot: SummarySnapshot { entry.snapshot }

    private let lime = Color(red: 0.6, green: 0.95, blue: 0.3)
    private var brandGradient: LinearGradient {
        LinearGradient(colors: [.cyan, lime], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium: medium
            case .systemLarge: large
            default: small
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.13),
                    Color(red: 0.10, green: 0.07, blue: 0.25),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.heroTitle)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(brandGradient)
            Text(snapshot.heroValue)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            if let heartRate = snapshot.avgHeartRate {
                Label(heartRate, systemImage: "heart.fill")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.pink)
            }
            Text(snapshot.periodPhrase)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.heroTitle)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(brandGradient)
                Text(snapshot.heroValue)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text(snapshot.periodPhrase)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                if let far = snapshot.far {
                    statRow("point.topleft.down.to.point.bottomright.curvepath.fill", far)
                }
                statRow("clock.fill", snapshot.long)
                if let much = snapshot.much {
                    statRow("flame.fill", much)
                }
                statRow("number", snapshot.many)
                if let heartRate = snapshot.avgHeartRate {
                    statRow("heart.fill", heartRate, tint: .pink)
                }
            }
        }
    }

    private func statRow(_ symbol: String, _ value: String, tint: Color? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(brandGradient))
                .frame(width: 13)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: Large

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                (Text("How Far").foregroundStyle(.white)
                    + Text("/Much").foregroundStyle(brandGradient))
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                Spacer()
                Text(snapshot.periodPhrase)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    tile("How Far", symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", value: snapshot.far)
                    tile("How Long", symbol: "clock.fill", value: snapshot.long)
                }
                GridRow {
                    tile("How Much", symbol: "flame.fill", value: snapshot.much)
                    tile("How Many", symbol: "number", value: snapshot.many)
                }
            }
            HStack {
                if let heartRate = snapshot.avgHeartRate {
                    Label("avg \(heartRate)", systemImage: "heart.fill")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.pink)
                }
                Spacer()
                Text(snapshot.activities)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func tile(_ title: String, symbol: String, value: String?) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(brandGradient)
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value ?? "—")
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.07))
        )
    }
}
