import SwiftUI

/// A squashed, collapsible version of the dashboard's period + metric pickers,
/// so you can change the comparison basis without leaving the Friends tab.
struct CompactControlsView: View {
    @Bindable var viewModel: SummaryViewModel
    @Binding var expanded: Bool

    private let brandGradient = LinearGradient(
        colors: [.cyan, Color(red: 0.6, green: 0.95, blue: 0.3)],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.spring(duration: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.metric.symbolName)
                    Text("\(viewModel.metric.rawValue) · \(viewModel.period.phrase)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)

            if expanded {
                periodPills
                metricPills
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.06))
        )
    }

    private var periodPills: some View {
        HStack(spacing: 6) {
            ForEach(Period.allCases) { period in
                Button {
                    withAnimation(.spring(duration: 0.3)) { viewModel.period = period }
                } label: {
                    Text(period.rawValue)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(
                            viewModel.period == period
                                ? AnyShapeStyle(brandGradient)
                                : AnyShapeStyle(.white.opacity(0.08))))
                        .foregroundStyle(viewModel.period == period ? .black : .white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var metricPills: some View {
        HStack(spacing: 6) {
            ForEach(Metric.allCases) { metric in
                Button {
                    withAnimation(.spring(duration: 0.3)) { viewModel.metric = metric }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: metric.symbolName).font(.caption2.weight(.semibold))
                        Text(metric.rawValue.replacingOccurrences(of: "How ", with: ""))
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(viewModel.metric == metric ? .white.opacity(0.15) : .white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(viewModel.metric == metric ? .cyan : .clear, lineWidth: 1.5)))
                    .foregroundStyle(viewModel.metric == metric ? .cyan : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
