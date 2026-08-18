import SwiftUI
import SwiftData

struct ShowDetailView: View {
    let tmdbID: Int
    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Query private var shows: [Show]
    @State private var viewModel = ShowDetailViewModel()
    @State private var confirmDelete = false
    @State private var isRefreshing = false
    @State private var refreshError: String?

    init(tmdbID: Int) {
        self.tmdbID = tmdbID
        let identifier = tmdbID
        _shows = Query(filter: #Predicate<Show> { $0.tmdbID == identifier })
    }

    private var show: Show? { shows.first }

    var body: some View {
        Group {
            if let show {
                detail(for: show)
            } else {
                EmptyStateView(
                    title: "Show not found",
                    systemImage: "tv.slash",
                    message: "This title is not in your library."
                )
            }
        }
        .pirateScreen()
        .navigationTitle(show?.name ?? "Show")
        .task(id: tmdbID) {
            await viewModel.loadExtras(tmdbID: tmdbID)
        }
    }

    private func detail(for show: Show) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                banner(for: show)
                VStack(alignment: .leading, spacing: 20) {
                    metadata(for: show)
                    WatchProgressBar(progress: show.progress, height: 10)
                    Text("\(show.watchedCount) of \(show.airedCount) aired episodes watched")
                        .font(.caption)
                        .foregroundStyle(Theme.parchment.opacity(0.7))
                    if !show.overview.isEmpty {
                        Text(show.overview)
                            .foregroundStyle(Theme.parchment.opacity(0.8))
                    }
                    extras()
                    ForEach(show.sortedSeasons) { season in
                        seasonBlock(season, show: show)
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            if viewModel.expandedSeason == nil {
                viewModel.expandedSeason = show.cachedNextUnwatchedSeason == 0
                    ? show.sortedSeasons.first?.seasonNumber
                    : show.cachedNextUnwatchedSeason
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    Task { await refreshFromTMDB(show) }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing)
                .help("Update this show from TMDB without losing watch progress")

                Button {
                    viewModel.setShowWatched(show, watched: show.hasUnwatchedAired, store: store)
                } label: {
                    Label(
                        show.hasUnwatchedAired ? "Watched Everything" : "Unwatch All",
                        systemImage: show.hasUnwatchedAired ? "checkmark.circle" : "arrow.uturn.backward.circle"
                    )
                }
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Remove from Library", systemImage: "trash")
                }
            }
        }
        .alert("Refresh failed", isPresented: Binding(
            get: { refreshError != nil },
            set: { if !$0 { refreshError = nil } }
        )) {
            Button("OK", role: .cancel) {
                refreshError = nil
            }
        } message: {
            Text(refreshError ?? "")
        }
        .alert("Remove \(show.name)?", isPresented: $confirmDelete) {
            Button("Remove", role: .destructive) {
                try? store.removeFromLibrary(show)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the show and its watch progress from your catalog.")
        }
    }

    private func banner(for show: Show) -> some View {
        ZStack(alignment: .bottomLeading) {
            BannerView(path: show.backdropPath ?? show.posterPath, size: .backdrop)

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.78)
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 16) {
                PosterView(path: show.posterPath, width: 120)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
                VStack(alignment: .leading, spacing: 6) {
                    Text(show.name)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(Theme.cream)
                    Text(metaLine(for: show))
                        .foregroundStyle(Theme.gold)
                }
                .padding(.bottom, 8)
                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }

    private func metadata(for show: Show) -> some View {
        HStack(spacing: 16) {
            Label(show.status, systemImage: "dot.radiowaves.left.and.right")
            if !show.networks.isEmpty {
                Label(show.networks, systemImage: "antenna.radiowaves.left.and.right")
            }
            if !show.genreNames.isEmpty {
                Label(show.genreNames.joined(separator: " · "), systemImage: "tag")
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.cyan)
        .lineLimit(1)
    }

    @ViewBuilder
    private func extras() -> some View {
        if !viewModel.providers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Where to Watch", subtitle: "Streaming in your region.")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.providers) { provider in
                            WatchProviderChip(provider: provider)
                        }
                    }
                }
                if let link = viewModel.providerLink {
                    Link("JustWatch", destination: link)
                        .font(.caption)
                        .foregroundStyle(Theme.cyan)
                }
            }
        }

        if !viewModel.cast.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Cast")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(viewModel.cast.prefix(16)) { member in
                            CastMemberCard(member: member)
                        }
                    }
                }
            }
        }

        if !viewModel.crew.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Crew")
                FlowCrewList(crew: viewModel.crew)
            }
        }
    }

    private func seasonBlock(_ season: Season, show: Show) -> some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        if viewModel.expandedSeason == season.seasonNumber {
                            viewModel.expandedSeason = nil
                        } else {
                            viewModel.expandedSeason = season.seasonNumber
                        }
                    } label: {
                        Image(systemName: viewModel.expandedSeason == season.seasonNumber ? "chevron.down" : "chevron.right")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help(viewModel.expandedSeason == season.seasonNumber ? "Collapse season" : "Expand season")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(season.name)
                            .font(.headline)
                        Text("\(season.watchedCount)/\(season.airedCount) watched")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        viewModel.toggleSeason(season, store: store)
                    } label: {
                        Label(
                            season.isFullyWatched ? "Unwatch Season" : "Watch Season",
                            systemImage: season.isFullyWatched ? "eye.slash" : "eye"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(season.isFullyWatched ? Theme.huntRed : Theme.watchedGreen)
                }
                WatchProgressBar(progress: season.progress, height: 8)
                if viewModel.expandedSeason == season.seasonNumber {
                    Divider().padding(.vertical, 4)
                    ForEach(season.sortedEpisodes) { episode in
                        EpisodeRow(episode: episode) {
                            viewModel.toggleEpisode(episode, store: store)
                        }
                    }
                }
            }
        }
    }

    private func metaLine(for show: Show) -> String {
        var parts: [String] = []
        if !show.yearLabel.isEmpty { parts.append(show.yearLabel) }
        parts.append("\(show.cachedSeasonCount) seasons")
        parts.append("\(show.totalEpisodeCount) episodes")
        return parts.joined(separator: " · ")
    }

    private func refreshFromTMDB(_ show: Show) async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await store.refreshShow(show)
        } catch {
            refreshError = error.localizedDescription
        }
    }
}

private struct CastMemberCard: View {
    let member: TMDBCastMember

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedRemoteImage(url: ImageURLBuilder.url(path: member.profilePath, size: .posterSmall)) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.navy)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Theme.parchment.opacity(0.6))
                    }
            }
            .frame(width: 92, height: 138)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(member.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.cream)
                .lineLimit(2)
                .frame(width: 92, alignment: .leading)
            Text(member.character ?? "")
                .font(.caption2)
                .foregroundStyle(Theme.parchment.opacity(0.7))
                .lineLimit(2)
                .frame(width: 92, alignment: .leading)
        }
    }
}

private struct WatchProviderChip: View {
    let provider: TMDBWatchProvider

    var body: some View {
        HStack(spacing: 8) {
            CachedRemoteImage(url: ImageURLBuilder.url(path: provider.logoPath, size: .logo)) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.navy)
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(provider.providerName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.cream)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

private struct FlowCrewList: View {
    let crew: [TMDBCrewMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(crew, id: \.stableID) { member in
                HStack {
                    Text(member.name)
                        .foregroundStyle(Theme.cream)
                    Spacer()
                    Text(member.job ?? "")
                        .foregroundStyle(Theme.parchment.opacity(0.7))
                }
                .font(.subheadline)
            }
        }
    }
}
