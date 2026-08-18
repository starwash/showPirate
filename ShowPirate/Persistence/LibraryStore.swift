import Foundation
import SwiftData

struct LibraryRefreshResult: Equatable {
    var refreshed: Int
    var failed: Int
}

@Observable
@MainActor
final class LibraryStore {
    private let context: ModelContext

    private(set) var calendarMarkedDays: Set<Date> = []
    private(set) var libraryShowIDs: Set<Int> = []
    private(set) var dashboardSnapshot = DashboardSnapshot(
        continueWatching: [],
        upcoming: [],
        recentlyAired: [],
        stats: .empty
    )
    private var calendarItemsByDay: [Date: [CalendarDayItem]] = [:]

    init(context: ModelContext) {
        self.context = context
        refreshDerivedData()
    }

    func calendarItems(on day: Date) -> [CalendarDayItem] {
        calendarItemsByDay[day.startOfDay] ?? []
    }

    func show(tmdbID: Int) -> Show? {
        var descriptor = FetchDescriptor<Show>(
            predicate: #Predicate { $0.tmdbID == tmdbID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func warmWatchCaches() async {
        let shows = (try? context.fetch(FetchDescriptor<Show>())) ?? []
        var didRebuild = false
        for show in shows where !show.watchCacheBuilt || show.watchCacheVersion < Show.currentWatchCacheVersion {
            show.rebuildWatchCache()
            didRebuild = true
            await Task.yield()
        }
        if didRebuild {
            try? context.save()
        }
        refreshDerivedData(using: shows)
    }

    func addToLibrary(details: TMDBShowDetails, seasons: [TMDBSeasonDetails], markWatched: Bool = false) throws {
        if let existing = show(tmdbID: details.id) {
            existing.inLibrary = true
            existing.lastUpdated = .now
            if markWatched {
                markAllAired(on: existing, watched: true)
            }
            existing.rebuildWatchCache()
            try context.save()
            refreshDerivedData()
            return
        }

        let show = Show(
            tmdbID: details.id,
            name: details.name,
            overview: details.overview ?? "",
            posterPath: details.posterPath,
            backdropPath: details.backdropPath,
            status: details.status ?? "Returning Series",
            firstAirDate: Formatters.parseTMDBDate(details.firstAirDate),
            networks: (details.networks ?? []).map(\.name).joined(separator: ", "),
            episodeRuntime: details.episodeRunTime?.first ?? 45,
            inLibrary: true,
            voteAverage: details.voteAverage ?? 0,
            originalLanguage: details.originalLanguage ?? "en"
        )

        for genreDTO in details.genres ?? [] {
            show.genres.append(genre(tmdbID: genreDTO.id, name: genreDTO.name))
        }

        for seasonDTO in seasons where seasonDTO.seasonNumber > 0 {
            show.seasons.append(makeSeason(from: seasonDTO, show: show))
        }

        if markWatched {
            markAllAired(on: show, watched: true)
        }

        show.rebuildWatchCache()
        context.insert(show)
        try context.save()
        refreshDerivedData()
    }

    func refreshShow(_ show: Show) async throws {
        let tmdbID = show.tmdbID
        let (details, seasons) = try await TMDBService.shared.fetchShowWithSeasons(id: tmdbID)
        guard let show = self.show(tmdbID: tmdbID) else { return }
        try merge(details: details, seasons: seasons, into: show)
    }

    func refreshLibrary() async -> LibraryRefreshResult {
        let descriptor = FetchDescriptor<Show>(
            predicate: #Predicate { $0.inLibrary }
        )
        let shows = (try? context.fetch(descriptor)) ?? []
        let maxConcurrent = 3
        var refreshed = 0
        var failed = 0
        var index = 0

        await withTaskGroup(of: (Bool).self) { group in
            func enqueueNext() {
                guard index < shows.count else { return }
                let show = shows[index]
                index += 1
                group.addTask { @MainActor in
                    do {
                        try await self.refreshShow(show)
                        return true
                    } catch {
                        return false
                    }
                }
            }

            for _ in 0..<min(maxConcurrent, shows.count) {
                enqueueNext()
            }

            while let success = await group.next() {
                if success {
                    refreshed += 1
                } else {
                    failed += 1
                }
                enqueueNext()
            }
        }

        if refreshed > 0 || failed == 0 {
            CatalogAutoRefresh.markRefreshed()
        }
        refreshDerivedData()
        return LibraryRefreshResult(refreshed: refreshed, failed: failed)
    }

    func removeFromLibrary(_ show: Show) throws {
        context.delete(show)
        try context.save()
        refreshDerivedData()
    }

    func setEpisode(_ episode: Episode, watched: Bool) throws {
        guard let show = episode.season?.show else { return }
        let wasWatched = episode.isWatched
        episode.isWatched = watched
        episode.watchedAt = watched ? .now : nil
        show.lastUpdated = .now
        if wasWatched != watched {
            show.applyEpisodeWatchChange(episode, wasWatched: wasWatched, isWatched: watched)
        }
        try context.save()
        refreshDerivedData()
    }

    func setSeason(_ season: Season, watched: Bool) throws {
        let now = Date()
        for episode in season.episodes where episode.hasAired || !watched {
            episode.isWatched = watched
            episode.watchedAt = watched ? now : nil
        }
        season.show?.lastUpdated = now
        season.show?.rebuildWatchCache()
        try context.save()
        refreshDerivedData()
    }

    func setShow(_ show: Show, watched: Bool) throws {
        markAllAired(on: show, watched: watched)
        show.lastUpdated = .now
        show.rebuildWatchCache()
        try context.save()
        refreshDerivedData()
    }

    private func markAllAired(on show: Show, watched: Bool) {
        let now = Date()
        for episode in show.allEpisodes where episode.hasAired || !watched {
            episode.isWatched = watched
            episode.watchedAt = watched ? now : nil
        }
    }

    private func refreshDerivedData(using shows: [Show]? = nil) {
        let library = libraryShows(from: shows)

        var marked: Set<Date> = []
        var grouped: [Date: [CalendarDayItem]] = [:]
        let decoder = JSONDecoder()

        for show in library {
            guard let data = show.cachedAirBeatsJSON.data(using: .utf8),
                  let beats = try? decoder.decode([CachedAirBeat].self, from: data) else {
                continue
            }
            for beat in beats {
                let day = Date(timeIntervalSince1970: TimeInterval(beat.t)).startOfDay
                marked.insert(day)
                grouped[day, default: []].append(
                    CalendarDayItem(
                        showID: show.tmdbID,
                        showName: show.name,
                        posterPath: show.posterPath,
                        season: beat.s,
                        episode: beat.e,
                        name: beat.n,
                        airDate: day
                    )
                )
            }
        }

        for day in grouped.keys {
            grouped[day]?.sort {
                if $0.showName != $1.showName {
                    return $0.showName.localizedCaseInsensitiveCompare($1.showName) == .orderedAscending
                }
                if $0.season != $1.season { return $0.season < $1.season }
                return $0.episode < $1.episode
            }
        }

        calendarMarkedDays = marked
        calendarItemsByDay = grouped
        libraryShowIDs = Set(library.map(\.tmdbID))
        dashboardSnapshot = DashboardProjector.snapshot(from: library)
    }

    private func libraryShows(from shows: [Show]?) -> [Show] {
        if let shows {
            return shows.filter(\.inLibrary)
        }
        var descriptor = FetchDescriptor<Show>(
            predicate: #Predicate { $0.inLibrary },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func clearLibrary() throws {
        try deleteAll()
    }

    func deleteAll() throws {
        for show in try context.fetch(FetchDescriptor<Show>()) {
            context.delete(show)
        }
        for genre in try context.fetch(FetchDescriptor<Genre>()) {
            context.delete(genre)
        }
        try context.save()
        refreshDerivedData()
    }

    private func merge(details: TMDBShowDetails, seasons: [TMDBSeasonDetails], into show: Show) throws {
        show.name = details.name
        show.overview = details.overview ?? show.overview
        show.posterPath = details.posterPath ?? show.posterPath
        show.backdropPath = details.backdropPath ?? show.backdropPath
        show.status = details.status ?? show.status
        if let firstAir = Formatters.parseTMDBDate(details.firstAirDate) {
            show.firstAirDate = firstAir
        }
        if let networks = details.networks, !networks.isEmpty {
            show.networks = networks.map(\.name).joined(separator: ", ")
        }
        if let runtime = details.episodeRunTime?.first {
            show.episodeRuntime = runtime
        }
        show.voteAverage = details.voteAverage ?? show.voteAverage
        show.originalLanguage = details.originalLanguage ?? show.originalLanguage
        show.lastUpdated = .now

        for genreDTO in details.genres ?? [] {
            let merged = genre(tmdbID: genreDTO.id, name: genreDTO.name)
            if !show.genres.contains(where: { $0.tmdbID == merged.tmdbID }) {
                show.genres.append(merged)
            }
        }

        for seasonDTO in seasons where seasonDTO.seasonNumber > 0 {
            if let existing = show.seasons.first(where: { $0.seasonNumber == seasonDTO.seasonNumber }) {
                merge(seasonDTO: seasonDTO, into: existing, show: show)
            } else {
                show.seasons.append(makeSeason(from: seasonDTO, show: show))
            }
        }

        show.rebuildWatchCache()
        try context.save()
        refreshDerivedData()
    }

    private func merge(seasonDTO: TMDBSeasonDetails, into season: Season, show: Show) {
        season.tmdbID = seasonDTO.id
        season.name = seasonDTO.name
        season.overview = seasonDTO.overview ?? season.overview
        season.posterPath = seasonDTO.posterPath ?? season.posterPath
        season.episodeCount = seasonDTO.episodes?.count ?? season.episodeCount
        if let airDate = Formatters.parseTMDBDate(seasonDTO.airDate) {
            season.airDate = airDate
        }

        for episodeDTO in seasonDTO.episodes ?? [] {
            if let existing = season.episodes.first(where: { $0.episodeNumber == episodeDTO.episodeNumber }) {
                existing.tmdbID = episodeDTO.id
                existing.name = episodeDTO.name ?? existing.name
                existing.overview = episodeDTO.overview ?? existing.overview
                if let airDate = Formatters.parseTMDBDate(episodeDTO.airDate) {
                    existing.airDate = airDate
                }
                existing.runtime = episodeDTO.runtime ?? existing.runtime
                existing.stillPath = episodeDTO.stillPath ?? existing.stillPath
                existing.voteAverage = episodeDTO.voteAverage ?? existing.voteAverage
            } else {
                season.episodes.append(makeEpisode(from: episodeDTO, show: show, season: season))
            }
        }
    }

    private func makeSeason(from seasonDTO: TMDBSeasonDetails, show: Show) -> Season {
        let season = Season(
            tmdbID: seasonDTO.id,
            seasonNumber: seasonDTO.seasonNumber,
            name: seasonDTO.name,
            overview: seasonDTO.overview ?? "",
            posterPath: seasonDTO.posterPath,
            episodeCount: seasonDTO.episodes?.count ?? 0,
            airDate: Formatters.parseTMDBDate(seasonDTO.airDate),
            show: show
        )
        for episodeDTO in seasonDTO.episodes ?? [] {
            season.episodes.append(makeEpisode(from: episodeDTO, show: show, season: season))
        }
        return season
    }

    private func makeEpisode(from episodeDTO: TMDBEpisode, show: Show, season: Season) -> Episode {
        Episode(
            tmdbID: episodeDTO.id,
            episodeNumber: episodeDTO.episodeNumber,
            name: episodeDTO.name ?? "Episode \(episodeDTO.episodeNumber)",
            overview: episodeDTO.overview ?? "",
            airDate: Formatters.parseTMDBDate(episodeDTO.airDate),
            runtime: episodeDTO.runtime ?? show.episodeRuntime,
            stillPath: episodeDTO.stillPath,
            voteAverage: episodeDTO.voteAverage ?? 0,
            season: season
        )
    }

    private func genre(tmdbID: Int, name: String) -> Genre {
        var descriptor = FetchDescriptor<Genre>(
            predicate: #Predicate { $0.tmdbID == tmdbID }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.name = name
            return existing
        }
        let genre = Genre(tmdbID: tmdbID, name: name)
        context.insert(genre)
        return genre
    }
}
