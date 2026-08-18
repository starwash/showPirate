import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    var results: [TMDBSearchShow] = []
    var trending: [TMDBSearchShow] = []
    var popular: [TMDBSearchShow] = []
    var onAir: [TMDBSearchShow] = []
    var isSearching = false
    var isLoadingDiscover = false
    var errorMessage: String?
    var addingIDs: Set<Int> = []

    private var searchTask: Task<Void, Never>?
    private let service: TMDBService

    init(service: TMDBService = .shared) {
        self.service = service
    }

    var isQueryEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func queryChanged() {
        searchTask?.cancel()
        let current = query
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            await self?.search(current)
        }
    }

    func loadDiscover(force: Bool = false) async {
        guard force || (trending.isEmpty && popular.isEmpty && onAir.isEmpty) else { return }
        guard APIConfig.hasAPIKey else {
            errorMessage = TMDBError.missingAPIKey.localizedDescription
            return
        }
        errorMessage = nil
        isLoadingDiscover = true
        defer { isLoadingDiscover = false }
        do {
            async let trendingTask = service.trendingTV()
            async let popularTask = service.popularTV()
            async let onAirTask = service.onTheAirTV()
            trending = try await trendingTask
            popular = try await popularTask
            onAir = try await onAirTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func search(_ raw: String? = nil) async {
        let term = (raw ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        guard !term.isEmpty else {
            results = []
            isSearching = false
            return
        }
        guard APIConfig.hasAPIKey else {
            results = []
            errorMessage = TMDBError.missingAPIKey.localizedDescription
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            results = try await service.searchTV(query: term)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }

    func addToLibrary(id: Int, store: LibraryStore, markWatched: Bool = false) async {
        addingIDs.insert(id)
        defer { addingIDs.remove(id) }
        do {
            let (details, seasons) = try await service.fetchShowWithSeasons(id: id)
            try store.addToLibrary(details: details, seasons: seasons, markWatched: markWatched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CalendarDayItem: Identifiable {
    var showID: Int
    var showName: String
    var posterPath: String?
    var season: Int
    var episode: Int
    var name: String
    var airDate: Date

    var id: String { "\(showID)-\(season)-\(episode)" }

    var code: String {
        String(format: "S%02dE%02d", season, episode)
    }

    var isAiringToday: Bool {
        Calendar.current.isDateInToday(airDate)
    }
}

@Observable
@MainActor
final class CalendarViewModel {
    var month: Date = Calendar.current.startOfMonth(for: .now)
    var selectedDay: Date = Date().startOfDay

    func previousMonth() {
        month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
    }

    func nextMonth() {
        month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
    }

    func goToToday() {
        month = Calendar.current.startOfMonth(for: .now)
        selectedDay = Date().startOfDay
    }
}

@Observable
@MainActor
final class ShowDetailViewModel {
    var expandedSeason: Int?
    var cast: [TMDBCastMember] = []
    var crew: [TMDBCrewMember] = []
    var providers: [TMDBWatchProvider] = []
    var providerLink: URL?
    var extrasError: String?

    func toggleEpisode(_ episode: Episode, store: LibraryStore) {
        try? store.setEpisode(episode, watched: !episode.isWatched)
    }

    func toggleSeason(_ season: Season, store: LibraryStore) {
        try? store.setSeason(season, watched: !season.isFullyWatched)
    }

    func setShowWatched(_ show: Show, watched: Bool, store: LibraryStore) {
        try? store.setShow(show, watched: watched)
    }

    func loadExtras(tmdbID: Int) async {
        extrasError = nil
        do {
            async let creditsTask = TMDBService.shared.fetchCredits(showID: tmdbID)
            async let providersTask = TMDBService.shared.fetchWatchProviders(showID: tmdbID)
            let credits = try await creditsTask
            let region = try await providersTask

            cast = credits.cast.sorted { ($0.order ?? 999) < ($1.order ?? 999) }
            crew = Self.featuredCrew(from: credits.crew)
            providers = region?.streaming ?? []
            if let link = region?.link {
                providerLink = URL(string: link)
            }
        } catch {
            extrasError = error.localizedDescription
        }
    }

    private static let featuredJobs: Set<String> = [
        "Creator", "Executive Producer", "Director", "Writer", "Novel", "Showrunner"
    ]

    private static func featuredCrew(from crew: [TMDBCrewMember]) -> [TMDBCrewMember] {
        var seen: Set<Int> = []
        return crew.filter { member in
            guard let job = member.job, featuredJobs.contains(job) else { return false }
            return seen.insert(member.id).inserted
        }
        .prefix(10)
        .map { $0 }
    }
}

struct DashboardSnapshot {
    var continueWatching: [Show]
    var upcoming: [CalendarDayItem]
    var recentlyAired: [CalendarDayItem]
    var stats: WatchStats
}

enum DashboardProjector {
    static func snapshot(from shows: [Show], upcomingLimit: Int = 12, recentLimit: Int = 12) -> DashboardSnapshot {
        let library = shows.filter(\.inLibrary)
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? .distantPast
        let today = Date().startOfDay
        let cutoffDay = cutoff.startOfDay
        let decoder = JSONDecoder()

        var continueWatching: [Show] = []
        var upcoming: [CalendarDayItem] = []
        var recentlyAired: [CalendarDayItem] = []
        var watchedEpisodes = 0
        var minutes = 0
        var completedShows = 0
        var genreTally: [String: Int] = [:]

        for show in library {
            if show.cachedHasUnwatchedAired {
                continueWatching.append(show)
            }
            watchedEpisodes += show.cachedWatchedCount
            minutes += show.cachedWatchedMinutes
            if show.isCompleted {
                completedShows += 1
            }
            if show.cachedWatchedCount > 0 {
                for genre in show.genreNames {
                    genreTally[genre, default: 0] += show.cachedWatchedCount
                }
            }

            guard let data = show.cachedAirBeatsJSON.data(using: .utf8),
                  let beats = try? decoder.decode([CachedAirBeat].self, from: data) else {
                continue
            }

            var nextUpcoming: CalendarDayItem?
            for beat in beats {
                let day = Date(timeIntervalSince1970: TimeInterval(beat.t)).startOfDay
                let item = CalendarDayItem(
                    showID: show.tmdbID,
                    showName: show.name,
                    posterPath: show.posterPath,
                    season: beat.s,
                    episode: beat.e,
                    name: beat.n,
                    airDate: day
                )
                if day > today {
                    if nextUpcoming == nil || day < nextUpcoming!.airDate {
                        nextUpcoming = item
                    }
                } else if day >= cutoffDay {
                    recentlyAired.append(item)
                }
            }
            if let nextUpcoming {
                upcoming.append(nextUpcoming)
            }
        }

        continueWatching.sort {
            ($0.cachedLastWatchedAt ?? .distantPast) > ($1.cachedLastWatchedAt ?? .distantPast)
        }
        upcoming.sort { $0.airDate < $1.airDate }
        recentlyAired.sort { $0.airDate > $1.airDate }

        let ranked = genreTally
            .map { (name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.name < $1.name }
                return $0.count > $1.count
            }

        return DashboardSnapshot(
            continueWatching: continueWatching,
            upcoming: Array(upcoming.prefix(upcomingLimit)),
            recentlyAired: Array(recentlyAired.prefix(recentLimit)),
            stats: WatchStats(
                watchedEpisodes: watchedEpisodes,
                watchedShows: completedShows,
                showsInLibrary: library.count,
                minutesWatched: minutes,
                genreCounts: ranked
            )
        )
    }

    static func continueWatching(from shows: [Show]) -> [Show] {
        snapshot(from: shows).continueWatching
    }

    static func upcoming(from shows: [Show], limit: Int = 12) -> [CalendarDayItem] {
        snapshot(from: shows, upcomingLimit: limit).upcoming
    }

    static func recentlyAired(from shows: [Show], limit: Int = 12) -> [CalendarDayItem] {
        snapshot(from: shows, recentLimit: limit).recentlyAired
    }
}
