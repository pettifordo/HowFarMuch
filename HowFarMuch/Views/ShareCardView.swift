import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Plain data the share card renders from

struct ShareCardData: Sendable {
    let periodPhrase: String
    let activities: String
    let farText: String?
    let longText: String
    let muchText: String?
    let manyText: String
    let isDemo: Bool
}

// MARK: - Shareable PNG, rendered lazily when the user commits the share

struct ShareCard: Transferable {
    let data: ShareCardData

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await MainActor.run { try render(card.data) }
        }
        .suggestedFileName("HowFarMuch.png")
    }

    @MainActor
    private static func render(_ data: ShareCardData) throws -> Data {
        let renderer = ImageRenderer(
            content: ShareCardView(data: data).environment(\.colorScheme, .dark)
        )
        renderer.scale = 3
        guard let image = renderer.uiImage, let png = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return png
    }
}

// MARK: - The card itself

struct ShareCardView: View {
    let data: ShareCardData

    private let brandGradient = LinearGradient(
        colors: [.cyan, Color(red: 0.6, green: 0.95, blue: 0.3)],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                LogoMarkView()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("How Far")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                    + Text("/Much")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(brandGradient)
                    Text("My workouts \(data.periodPhrase)")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
            }

            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    tile(metric: .far, value: data.farText)
                    tile(metric: .long, value: data.longText)
                }
                GridRow {
                    tile(metric: .much, value: data.muchText)
                    tile(metric: .many, value: data.manyText)
                }
            }

            Text(data.activities)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if data.isDemo {
                Label("Demo data", systemImage: "sparkles")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.yellow.opacity(0.9))
            }
        }
        .padding(26)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.03, green: 0.05, blue: 0.12),
                            Color(red: 0.10, green: 0.07, blue: 0.26),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func tile(metric: Metric, value: String?) -> some View {
        VStack(spacing: 6) {
            Image(systemName: metric.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(brandGradient)
            Text(metric.rawValue)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Text(value ?? "—")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.07))
        )
    }
}

#Preview {
    ShareCardView(data: ShareCardData(
        periodPhrase: "in the last 7 days",
        activities: "Running, Cycling, Walking",
        farText: "58 mi",
        longText: "8h 45m",
        muchText: "4,969 kcal",
        manyText: "12 workouts",
        isDemo: true
    ))
}
