import SwiftUI

/// The "Friends" tab: received reactions, and a card per friend showing a
/// head-to-head comparison of you vs them for the selected metric & period.
struct FriendsTabView: View {
    @Bindable var viewModel: SummaryViewModel
    @Bindable var friendsViewModel: FriendsViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        periodMetricNote
                        if !friendsViewModel.receivedReactions.isEmpty {
                            reactionsStrip
                        }
                        if let message = friendsViewModel.statusMessage {
                            Text(message)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                        if friendsViewModel.awaitingFeeds > 0 {
                            awaitingNote
                        }
                        if friendsViewModel.friends.isEmpty {
                            emptyState
                        }
                        ForEach(friendsViewModel.friends) { friend in
                            NavigationLink {
                                FriendDetailView(
                                    friend: friend,
                                    initialPeriod: viewModel.period,
                                    friendsViewModel: friendsViewModel
                                )
                            } label: {
                                FriendComparisonCard(
                                    friend: friend,
                                    period: viewModel.period,
                                    metric: viewModel.metric,
                                    myValue: viewModel.myValue(for: viewModel.metric)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .padding(.bottom, 32)
                }
                .refreshable { await friendsViewModel.refresh() }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Friends")
                .font(.system(.title, design: .rounded, weight: .heavy))
            if friendsViewModel.isDemo {
                Text("demo")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.yellow.opacity(0.9))
            }
            Spacer()
            Button {
                Task { await friendsViewModel.invite() }
            } label: {
                Label("Invite", systemImage: "person.badge.plus")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.cyan.opacity(0.18)))
                    .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)
        }
    }

    private var periodMetricNote: some View {
        Text("Comparing \(viewModel.metric.rawValue.lowercased()) \(viewModel.period.phrase). Change these on the Me tab.")
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
    }

    private var reactionsStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(friendsViewModel.receivedReactions.prefix(4)) { reaction in
                HStack(spacing: 6) {
                    Text(reaction.kind.emoji)
                    Text("\(reaction.fromName) sent \(reaction.kind.label)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                    Text("· \(reaction.date.formatted(.relative(presentation: .named)))")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    private var awaitingNote: some View {
        Label(
            friendsViewModel.awaitingFeeds == 1
                ? "Invite accepted — totals appear once your friend opens the app"
                : "\(friendsViewModel.awaitingFeeds) invites accepted — totals appear once your friends open the app",
            systemImage: "hourglass"
        )
        .font(.system(.caption, design: .rounded, weight: .semibold))
        .foregroundStyle(.cyan)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.cyan)
            Text("Follow your friends")
                .font(.system(.headline, design: .rounded))
            Text("Send an invite and you'll see each other's totals side by side, and can trade Respect 🤜 and Whoops 🙈. They only ever see your totals — never individual workouts.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await friendsViewModel.invite() }
            } label: {
                Label("Invite a Friend", systemImage: "person.badge.plus")
                    .font(.system(.headline, design: .rounded))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(
                        LinearGradient(colors: [.cyan, Color(red: 0.6, green: 0.95, blue: 0.3)],
                                       startPoint: .leading, endPoint: .trailing)))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 12)
    }
}

// MARK: - Head-to-head card

struct FriendComparisonCard: View {
    let friend: FriendsService.Friend
    let period: Period
    let metric: Metric
    let myValue: Double

    private var theirValue: Double {
        guard let bucket = friend.feed.bucket(for: period) else { return 0 }
        return metric.bucketValue(bucket)
    }

    private var iLead: Bool { myValue >= theirValue }
    private var maxValue: Double { max(myValue, theirValue, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(friend.feed.emoji)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.08)))
                Text(friend.feed.name)
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Text(verdict)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(verdictColor)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            comparisonBar(label: "You", value: myValue, tint: .cyan, leading: iLead)
            comparisonBar(label: friend.feed.name, value: theirValue,
                          tint: Color(red: 0.6, green: 0.95, blue: 0.3), leading: !iLead && theirValue > 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func comparisonBar(label: String, value: Double, tint: Color, leading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                if leading {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text(metric.formatted(value))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(tint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, proxy.size.width * value / maxValue))
                }
            }
            .frame(height: 7)
        }
    }

    private var verdict: String {
        if theirValue == 0 && myValue == 0 { return "no data" }
        if abs(myValue - theirValue) < maxValue * 0.01 { return "level" }
        return iLead ? "you lead" : "behind"
    }

    private var verdictColor: Color {
        if theirValue == 0 && myValue == 0 { return .secondary }
        if abs(myValue - theirValue) < maxValue * 0.01 { return .secondary }
        return iLead ? .green : .orange
    }
}
