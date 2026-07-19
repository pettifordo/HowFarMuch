import SwiftUI

/// A friend's totals, browsable by period, with Respect/Whoops reactions.
struct FriendDetailView: View {
    let friend: FriendsService.Friend
    @Bindable var friendsViewModel: FriendsViewModel

    @State private var period: Period

    init(friend: FriendsService.Friend, initialPeriod: Period, friendsViewModel: FriendsViewModel) {
        self.friend = friend
        self.friendsViewModel = friendsViewModel
        _period = State(initialValue: initialPeriod)
    }

    private var bucket: PeriodBucket? {
        friend.feed.bucket(for: period)
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    periodPicker
                    if let bucket {
                        comparisonSection(bucket)
                        totalsGrid(bucket)
                        reactionButtons
                        activityCards(bucket)
                    } else {
                        Text("\(friend.feed.name) doesn't share totals for this period.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.top, 30)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(friend.feed.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text(friend.feed.emoji)
                .font(.system(size: 44))
            Text("Updated \(friend.feed.updated.formatted(.relative(presentation: .named)))")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(Period.allCases) { candidate in
                Button {
                    period = candidate
                } label: {
                    Text(candidate.rawValue)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(period == candidate ? .white.opacity(0.18) : .white.opacity(0.06))
                        )
                        .foregroundStyle(period == candidate ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - You vs them

    @ViewBuilder
    private func comparisonSection(_ bucket: PeriodBucket) -> some View {
        if let mine = friendsViewModel.myFeed?.bucket(for: period) {
            VStack(alignment: .leading, spacing: 10) {
                Text("You vs \(friend.feed.name)")
                    .font(.system(.headline, design: .rounded))
                ForEach(Metric.allCases) { metric in
                    comparisonRow(metric, mine: mine, theirs: bucket)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
        }
    }

    private func comparisonRow(_ metric: Metric, mine: PeriodBucket, theirs: PeriodBucket) -> some View {
        let myVal = metric.bucketValue(mine)
        let theirVal = metric.bucketValue(theirs)
        let iLead = myVal >= theirVal
        let maxVal = max(myVal, theirVal, 1)
        return VStack(spacing: 4) {
            HStack {
                Label(metric.rawValue, systemImage: metric.symbolName)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(metric.formatted(myVal))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("vs")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(metric.formatted(theirVal))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(red: 0.6, green: 0.95, blue: 0.3))
            }
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    Capsule().fill(.cyan)
                        .frame(width: barWidth(myVal, maxVal, proxy.size.width))
                    Capsule().fill(Color(red: 0.6, green: 0.95, blue: 0.3))
                        .frame(width: barWidth(theirVal, maxVal, proxy.size.width))
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 6)
            .opacity(iLead ? 1 : 0.9)
        }
    }

    private func barWidth(_ value: Double, _ maxVal: Double, _ total: CGFloat) -> CGFloat {
        // Two half-width lanes; each bar fills its lane proportionally.
        max(3, (total / 2 - 3) * value / maxVal)
    }

    // MARK: - Totals

    private func totalsGrid(_ bucket: PeriodBucket) -> some View {
        VStack(spacing: 10) {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    tile(.far, value: bucket.totalDistanceMeters > 0
                        ? Metric.far.formatted(bucket.totalDistanceMeters) : nil)
                    tile(.long, value: Metric.long.formatted(bucket.totalDurationSeconds))
                }
                GridRow {
                    tile(.much, value: bucket.totalKilocalories > 0
                        ? Metric.much.formatted(bucket.totalKilocalories) : nil)
                    tile(.many, value: Metric.many.formatted(Double(bucket.totalWorkouts)))
                }
            }
            if let heartRate = bucket.avgHeartRate {
                Label("avg \(Int(heartRate.rounded())) bpm", systemImage: "heart.fill")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.pink.opacity(0.9))
            }
        }
    }

    private func tile(_ metric: Metric, value: String?) -> some View {
        VStack(spacing: 4) {
            Image(systemName: metric.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.cyan)
            Text(metric.rawValue)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.system(.title3, design: .rounded, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }

    // MARK: - Respect / Whoops

    private var reactionButtons: some View {
        HStack(spacing: 10) {
            ForEach(ReactionKind.allCases, id: \.self) { kind in
                let justSent = friendsViewModel.lastSentReaction[friend.id] == kind
                Button {
                    Task { await friendsViewModel.sendReaction(kind, about: period, to: friend) }
                } label: {
                    HStack(spacing: 6) {
                        Text(kind.emoji)
                        Text(justSent ? "Sent!" : kind.label)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(
                            justSent
                                ? AnyShapeStyle(kind == .respect ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
                                : AnyShapeStyle(.white.opacity(0.08))
                        )
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            kind == .respect ? Color.green.opacity(0.5) : Color.orange.opacity(0.5),
                            lineWidth: 1
                        )
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: justSent)
            }
        }
    }

    // MARK: - Per-activity cards

    private func activityCards(_ bucket: PeriodBucket) -> some View {
        let stats = bucket.activities
            .map {
                ActivityStats(
                    type: $0.type,
                    workoutCount: $0.workoutCount,
                    totalDuration: $0.durationSeconds,
                    totalDistanceMeters: $0.distanceMeters,
                    totalEnergyKilocalories: $0.kilocalories
                )
            }
            .sorted { $0.totalDuration > $1.totalDuration }
        let maxDuration = stats.map(\.totalDuration).max() ?? 0
        return LazyVStack(spacing: 10) {
            ForEach(stats) { activity in
                ActivityCardView(stats: activity, metric: .long, maxValue: maxDuration)
            }
        }
    }
}
