import SwiftUI

/// The "Friends" tab. Three states: signed out (Sign in with Apple), needs a
/// handle (claim one), or ready (search, requests, friend comparison cards).
struct FriendsTabView: View {
    @Bindable var viewModel: SummaryViewModel
    @Bindable var friendsViewModel: FriendsViewModel

    @State private var controlsExpanded = true
    @State private var confirmHandle = false

    private let lime = Color(red: 0.6, green: 0.95, blue: 0.3)

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch friendsViewModel.state {
                        case .signedOut: signedOut
                        case .needsHandle: handleClaim
                        case .ready: ready
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

    // MARK: - Signed out

    private var signedOut: some View {
        VStack(spacing: 16) {
            LogoMarkView().frame(width: 60, height: 60).padding(.top, 40)
            Text("Follow your friends")
                .font(.system(.title, design: .rounded, weight: .heavy))
            Text("Sign in to pick a handle, then swap workout totals with friends and trade Respect 🤜 and Whoops 🙈. You only ever share summary totals — never individual workouts, dates or routes.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            AppleSignInButton(
                onSignedIn: { Task { await friendsViewModel.refresh() } },
                onError: { friendsViewModel.statusMessage = $0 }
            )
            .padding(.horizontal, 24)
            .padding(.top, 8)
            if let message = friendsViewModel.statusMessage {
                Text(message).font(.system(.caption, design: .rounded)).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Handle claim

    private var handleClaim: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pick your handle")
                .font(.system(.title2, design: .rounded, weight: .heavy))
            Text("This is how friends find you. Lowercase letters, numbers and underscores, 3–20 characters.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            HStack {
                Text("@").foregroundStyle(.secondary)
                TextField("yourhandle", text: $friendsViewModel.handleDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: friendsViewModel.handleDraft) { _, _ in
                        Task { await friendsViewModel.checkHandle() }
                    }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))

            if friendsViewModel.checkingHandle {
                Label("Checking…", systemImage: "hourglass").font(.caption).foregroundStyle(.secondary)
            } else if let available = friendsViewModel.handleAvailable {
                Label(available ? "Available" : "Not available",
                      systemImage: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(available ? .green : .orange)
            }

            Button {
                confirmHandle = true
            } label: {
                Text("Claim handle")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(friendsViewModel.handleAvailable == true
                        ? AnyShapeStyle(LinearGradient(colors: [.cyan, lime], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(.white.opacity(0.1))))
                    .foregroundStyle(friendsViewModel.handleAvailable == true ? .black : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(friendsViewModel.handleAvailable != true)
            .alert("Claim @\(friendsViewModel.handleDraft.lowercased())?", isPresented: $confirmHandle) {
                Button("Claim") { Task { await friendsViewModel.claimHandle() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This becomes your permanent handle — it can't be changed later. Friends will use it to find you.")
            }

            if let message = friendsViewModel.statusMessage {
                Text(message).font(.system(.caption, design: .rounded)).foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Ready

    private var ready: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Friends").font(.system(.title, design: .rounded, weight: .heavy))
                    if let handle = friendsViewModel.myHandle {
                        Text("@\(handle)")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                }
                Spacer()
                Menu {
                    if let handle = friendsViewModel.myHandle {
                        Section("Signed in as @\(handle)") {}
                    }
                    Button(role: .destructive) {
                        Task { await friendsViewModel.signOut() }
                    } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3).foregroundStyle(.secondary)
                }
            }

            CompactControlsView(viewModel: viewModel, expanded: $controlsExpanded)

            searchBar
            if let status = friendsViewModel.searchStatus {
                Text(status).font(.system(.caption, design: .rounded)).foregroundStyle(.cyan)
            }
            if let result = friendsViewModel.searchResult {
                searchResultCard(result)
            }

            if !friendsViewModel.incoming.isEmpty {
                Text("Requests").font(.system(.headline, design: .rounded)).padding(.top, 4)
                ForEach(friendsViewModel.incoming) { request in
                    requestCard(request)
                }
            }

            if !friendsViewModel.receivedReactions.isEmpty {
                reactionsStrip
            }

            if let message = friendsViewModel.statusMessage {
                Text(message).font(.system(.caption, design: .rounded)).foregroundStyle(.orange)
            }

            if friendsViewModel.friends.isEmpty && friendsViewModel.incoming.isEmpty {
                Text("No friends yet — search a handle above to send your first request.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            ForEach(friendsViewModel.friends) { friend in
                NavigationLink {
                    FriendDetailView(friend: friend, initialPeriod: viewModel.period,
                                     friendsViewModel: friendsViewModel)
                } label: {
                    FriendComparisonCard(friend: friend, period: viewModel.period,
                                         metric: viewModel.metric,
                                         myValue: viewModel.myValue(for: viewModel.metric))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "at").foregroundStyle(.secondary)
            TextField("Find a friend by handle", text: $friendsViewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await friendsViewModel.search() } }
            Button {
                Task { await friendsViewModel.search() }
            } label: { Image(systemName: "magnifyingglass").foregroundStyle(.cyan) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
    }

    private func searchResultCard(_ profile: SupabaseFriendsService.ProfileRow) -> some View {
        HStack(spacing: 12) {
            Text(profile.emoji).font(.title2)
                .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.08)))
            VStack(alignment: .leading) {
                Text(profile.displayName).font(.system(.headline, design: .rounded))
                Text("@\(profile.handle)").font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await friendsViewModel.sendRequest(to: profile) }
            } label: {
                Text("Add").font(.system(.subheadline, design: .rounded, weight: .bold))
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(.cyan.opacity(0.2))).foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.06)))
    }

    private func requestCard(_ request: SupabaseFriendsService.IncomingRequest) -> some View {
        HStack(spacing: 12) {
            Text(request.profile.emoji).font(.title2)
                .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.08)))
            VStack(alignment: .leading) {
                Text(request.profile.displayName).font(.system(.headline, design: .rounded))
                Text("@\(request.profile.handle) wants to compare")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await friendsViewModel.accept(request) } } label: {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green)
            }.buttonStyle(.plain)
            Button { Task { await friendsViewModel.decline(request) } } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(.cyan.opacity(0.08)))
    }

    private var reactionsStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(friendsViewModel.receivedReactions.prefix(4)) { reaction in
                HStack(spacing: 6) {
                    Text(reaction.kind.emoji)
                    Text("\(reaction.fromName) sent \(reaction.kind.label)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                    Text("· \(reaction.date.formatted(.relative(presentation: .named)))")
                        .font(.system(.caption2, design: .rounded)).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.05)))
    }
}

// MARK: - Head-to-head card

struct FriendComparisonCard: View {
    let friend: Friend
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
                Text(friend.feed.emoji).font(.title2)
                    .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.08)))
                Text(friend.feed.name).font(.system(.headline, design: .rounded))
                Spacer()
                Text(verdict).font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(verdictColor)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            comparisonBar(label: "You", value: myValue, tint: .cyan, leading: iLead)
            comparisonBar(label: friend.feed.name, value: theirValue,
                          tint: Color(red: 0.6, green: 0.95, blue: 0.3), leading: !iLead && theirValue > 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1))
        )
    }

    private func comparisonBar(label: String, value: Double, tint: Color, leading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(.secondary)
                if leading {
                    Image(systemName: "crown.fill").font(.caption2).foregroundStyle(.yellow)
                }
                Spacer()
                Text(metric.formatted(value)).font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(tint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(tint).frame(width: max(6, proxy.size.width * value / maxValue))
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
