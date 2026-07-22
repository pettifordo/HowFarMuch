import SwiftUI

/// The "Me" tab: your own workout totals — period, hero, metric, filters,
/// per-activity cards. Settings gear sits at the top.
struct DashboardView: View {
    @Bindable var viewModel: SummaryViewModel
    @Bindable var friendsViewModel: FriendsViewModel

    @State private var showSettings = false

    private let brandGradient = LinearGradient(
        colors: [.cyan, Color(red: 0.6, green: 0.95, blue: 0.3)],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        HStack(spacing: 8) {
                            LogoHeaderView()
                            settingsButton
                        }
                        periodPicker
                        heroPanel
                        metricPicker
                        if viewModel.allStats.count > 1 {
                            filterChips
                        }
                        activityList
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .refreshable { await viewModel.load() }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            Task {
                await viewModel.load()
                await friendsViewModel.pushProfileEdits()
                await friendsViewModel.refresh()
            }
        }) {
            SettingsView(
                availableTypes: viewModel.availableTypes,
                rawWorkouts: viewModel.fetchedWorkouts,
                periodPhrase: viewModel.period.phrase
            )
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.cyan)
                .frame(width: 38, height: 38)
                .background(Circle().fill(.white.opacity(0.08)))
        }
        .accessibilityLabel("Settings")
    }

    // MARK: - Period

    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(Period.allCases) { period in
                Button {
                    viewModel.period = period
                } label: {
                    Text(period.rawValue)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(
                                viewModel.period == period
                                    ? AnyShapeStyle(brandGradient)
                                    : AnyShapeStyle(.white.opacity(0.08))
                            )
                        )
                        .foregroundStyle(viewModel.period == period ? .black : .white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hero total

    private var heroPanel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.metric.symbolName)
                Text("\(viewModel.metric.rawValue) \(viewModel.period.phrase)")
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(.secondary)

            Text(viewModel.metric.formatted(viewModel.heroValue))
                .font(.system(size: 52, weight: .black, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(brandGradient)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4), value: viewModel.heroValue)

            if let heartRate = viewModel.averageHeartRate {
                Label("avg \(Int(heartRate.rounded())) bpm", systemImage: "heart.fill")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.pink.opacity(0.9))
            }

            if viewModel.duplicatesIgnored > 0 {
                Label(
                    viewModel.duplicatesIgnored == 1
                        ? "1 duplicate ignored"
                        : "\(viewModel.duplicatesIgnored) duplicates ignored",
                    systemImage: "rectangle.on.rectangle.slash"
                )
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
            }
            if viewModel.isDemoData && !ProcessInfo.processInfo.arguments.contains("-hideDemoBadge") {
                Label("Demo data — run on your iPhone to see real workouts", systemImage: "sparkles")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.yellow.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Metric

    private var metricPicker: some View {
        HStack(spacing: 8) {
            ForEach(Metric.allCases) { metric in
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        viewModel.metric = metric
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: metric.symbolName)
                            .font(.body.weight(.semibold))
                        Text(metric.rawValue.replacingOccurrences(of: "How ", with: ""))
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(viewModel.metric == metric ? .white.opacity(0.15) : .white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        viewModel.metric == metric ? .cyan : .clear,
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .foregroundStyle(viewModel.metric == metric ? .cyan : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Activity filters

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    withAnimation { viewModel.showAllActivities() }
                } label: {
                    Text("All")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                viewModel.hiddenActivityIDs.isEmpty
                                    ? .white.opacity(0.2)
                                    : .white.opacity(0.06)
                            )
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                ForEach(viewModel.allStats) { stats in
                    let isOn = !viewModel.hiddenActivityIDs.contains(stats.id)
                    Button {
                        withAnimation { viewModel.toggleFilter(for: stats) }
                    } label: {
                        Label(stats.type.displayName, systemImage: stats.type.symbolName)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isOn ? stats.type.tint.opacity(0.25) : .white.opacity(0.05))
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    isOn ? stats.type.tint.opacity(0.6) : .clear,
                                    lineWidth: 1
                                )
                            )
                            .foregroundStyle(isOn ? stats.type.tint : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Cards / states

    @ViewBuilder
    private var activityList: some View {
        if viewModel.isLoading && viewModel.allStats.isEmpty {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Reading your workouts from Apple Health…")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("The first load can take a moment if you have a lot of history.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)
        } else if let message = viewModel.errorMessage, viewModel.allStats.isEmpty {
            let waiting = message.hasPrefix("Waiting")
            emptyState(
                symbol: waiting ? "lock.rotation" : "heart.text.square",
                title: waiting ? "Just a moment…" : "Can't read Health data",
                message: message
            )
        } else if viewModel.allStats.isEmpty {
            emptyState(
                symbol: "figure.run.circle",
                title: "No workouts \(viewModel.period.phrase)",
                message: "Workouts you record on Apple Watch or iPhone will show up here. If you expected data, check Settings → Health → Data Access & Devices → How Far/Much."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.visibleStats) { stats in
                    NavigationLink {
                        ActivityDetailView(
                            type: stats.type,
                            workouts: viewModel.workouts(for: stats.type),
                            periodPhrase: viewModel.period.phrase,
                            defaultGrouping: viewModel.period.defaultGrouping
                        )
                    } label: {
                        ActivityCardView(
                            stats: stats,
                            metric: viewModel.metric,
                            maxValue: viewModel.maxMetricValue
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func emptyState(symbol: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 48))
                .foregroundStyle(.cyan)
            Text(title)
                .font(.system(.headline, design: .rounded))
            Text(message)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 48)
        .padding(.horizontal, 24)
    }
}
