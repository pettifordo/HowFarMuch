import SwiftUI

/// The Friends block on the dashboard: received reactions, friend cards,
/// and the invite button.
struct FriendsSectionView: View {
    @Bindable var friendsViewModel: FriendsViewModel
    let period: Period
    let metric: Metric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friends")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
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
                        .background(Capsule().fill(.white.opacity(0.08)))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
            }

            if !friendsViewModel.receivedReactions.isEmpty {
                reactionsStrip
            }

            if let message = friendsViewModel.statusMessage {
                Text(message)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.orange)
            }

            if friendsViewModel.awaitingFeeds > 0 {
                Label(
                    friendsViewModel.awaitingFeeds == 1
                        ? "Invite accepted — totals appear once your friend opens the app"
                        : "\(friendsViewModel.awaitingFeeds) invites accepted — totals appear once your friends open the app",
                    systemImage: "hourglass"
                )
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.cyan)
            }

            if friendsViewModel.friends.isEmpty && friendsViewModel.statusMessage == nil {
                Text("Invite someone to swap workout totals — you'll see each other's How Far, Long, Much and Many, and can trade Respect 🤜 and Whoops 🙈.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            ForEach(friendsViewModel.friends) { friend in
                NavigationLink {
                    FriendDetailView(
                        friend: friend,
                        initialPeriod: period,
                        friendsViewModel: friendsViewModel
                    )
                } label: {
                    friendCard(friend)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Received reactions

    private var reactionsStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(friendsViewModel.receivedReactions.prefix(3)) { reaction in
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

    // MARK: - Friend card

    private func friendCard(_ friend: FriendsService.Friend) -> some View {
        HStack(spacing: 12) {
            Text(friend.feed.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.feed.name)
                    .font(.system(.headline, design: .rounded))
                Text(summaryLine(for: friend))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(heroText(for: friend))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.cyan)
                Text(friend.feed.updated.formatted(.relative(presentation: .named)))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
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

    private func heroText(for friend: FriendsService.Friend) -> String {
        guard let bucket = friend.feed.bucket(for: period) else { return "—" }
        switch metric {
        case .far: return Metric.far.formatted(bucket.totalDistanceMeters)
        case .long: return Metric.long.formatted(bucket.totalDurationSeconds)
        case .much: return Metric.much.formatted(bucket.totalKilocalories)
        case .many: return Metric.many.formatted(Double(bucket.totalWorkouts))
        }
    }

    private func summaryLine(for friend: FriendsService.Friend) -> String {
        guard let bucket = friend.feed.bucket(for: period) else {
            return "Nothing shared for this period"
        }
        var parts = [Metric.many.formatted(Double(bucket.totalWorkouts))]
        if metric != .long {
            parts.append(Metric.long.formatted(bucket.totalDurationSeconds))
        }
        if metric != .much, bucket.totalKilocalories > 0 {
            parts.append(Metric.much.formatted(bucket.totalKilocalories))
        }
        return parts.joined(separator: " · ")
    }
}
