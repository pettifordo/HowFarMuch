import SwiftUI

/// The "Share" tab: brag about your totals (image or text), export your
/// workouts as CSV, and invite friends.
struct ShareTabView: View {
    @Bindable var viewModel: SummaryViewModel
    @Bindable var friendsViewModel: FriendsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Share & Brag")
                            .font(.system(.title, design: .rounded, weight: .heavy))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Showing your \(viewModel.metric.rawValue.lowercased()) \(viewModel.period.phrase). Change the period on the Me tab.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Live preview of the brag card
                        ShareCardView(data: viewModel.shareCardData)
                            .frame(maxWidth: .infinity)

                        VStack(spacing: 10) {
                            ShareLink(
                                item: ShareCard(data: viewModel.shareCardData),
                                preview: SharePreview("My workouts — How Far/Much")
                            ) {
                                actionRow("Share as Image", subtitle: "A picture of your totals", symbol: "photo.fill")
                            }
                            .buttonStyle(.plain)

                            ShareLink(item: viewModel.shareSummary) {
                                actionRow("Share as Text", subtitle: "Plain text summary", symbol: "text.alignleft")
                            }
                            .buttonStyle(.plain)

                            ShareLink(
                                item: WorkoutCSVExport(workouts: viewModel.visibleWorkouts),
                                preview: SharePreview("How Far/Much workouts (CSV)")
                            ) {
                                actionRow("Download CSV", subtitle: "Every workout as a spreadsheet", symbol: "tablecells.fill")
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await friendsViewModel.invite() }
                            } label: {
                                actionRow("Invite a Friend", subtitle: "Swap totals and trade reactions", symbol: "person.badge.plus.fill")
                            }
                            .buttonStyle(.plain)
                        }

                        if let message = friendsViewModel.statusMessage {
                            Text(message)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .padding(.bottom, 32)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func actionRow(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.cyan)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.cyan.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }
}
