import SwiftUI

struct DashboardView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        let snapshot = store.dashboardSnapshot
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                statsRow(snapshot.stats)
                continueSection(snapshot.continueWatching)
                upcomingSection(snapshot.upcoming)
                recentlyAiredSection(snapshot.recentlyAired)
            }
            .padding(24)
        }
        .pirateScreen()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Navigate your favorite shows.")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.parchment)
            Text("Pick up where you left off, and see what airs next.")
                .foregroundStyle(Theme.sky)
        }
    }

    private func statsRow(_ stats: WatchStats) -> some View {
        HStack(spacing: 14) {
            StatTile(title: "Watched", value: "\(stats.watchedEpisodes)", systemImage: "checkmark.circle", footnote: "episodes", accent: Theme.huntRed)
            StatTile(title: "Library", value: "\(stats.showsInLibrary)", systemImage: "rectangle.stack", footnote: "shows", accent: Theme.huntTeal)
            StatTile(title: "Time", value: stats.timeWatchedLabel, systemImage: "clock", footnote: "watched", accent: Theme.gold)
            StatTile(
                title: "Favourite",
                value: stats.favouriteGenres.first?.name ?? "—",
                systemImage: "sparkles",
                footnote: "genre",
                accent: Theme.huntTeal
            )
        }
    }

    private func continueSection(_ continueWatching: [Show]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Continue Watching", subtitle: continueWatching.isEmpty ? "You're all caught up." : "Jump back into a series.")
            if continueWatching.isEmpty {
                emptyStrip(icon: "checkmark.seal", text: "No in-progress shows.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(continueWatching) { show in
                            NavigationLink(value: show.tmdbID) {
                                ContinueWatchingCard(show: show)
                                    .frame(width: 320)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func upcomingSection(_ upcoming: [CalendarDayItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Upcoming Episodes", subtitle: "New episodes on the horizon.")
            if upcoming.isEmpty {
                emptyStrip(icon: "calendar.badge.clock", text: "Nothing scheduled yet.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                    ForEach(upcoming) { item in
                        NavigationLink(value: item.showID) {
                            CachedUpcomingEpisodeCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recentlyAiredSection(_ recentlyAired: [CalendarDayItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recently Aired", subtitle: "The last two weeks.")
            if recentlyAired.isEmpty {
                emptyStrip(icon: "sparkles.tv", text: "No recent air dates.")
            } else {
                GlassCard(padding: 8) {
                    ForEach(recentlyAired) { item in
                        NavigationLink(value: item.showID) {
                            HStack {
                                Text(item.showName)
                                    .font(.headline)
                                    .foregroundStyle(Theme.cream)
                                Text(item.code)
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundStyle(Theme.gold)
                                Text(item.name)
                                    .foregroundStyle(Theme.parchment.opacity(0.7))
                                    .lineLimit(1)
                                Spacer()
                                Text(Formatters.episodeAirLabel(item.airDate))
                                    .font(.caption)
                                    .foregroundStyle(Theme.cyan)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func emptyStrip(icon: String, text: String) -> some View {
        GlassCard {
            Label(text, systemImage: icon)
                .foregroundStyle(Theme.parchment.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
