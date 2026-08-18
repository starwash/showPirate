import Foundation
import SwiftData

@Model
final class Show {
    var tmdbID: Int = 0
    var name: String = ""
    var overview: String = ""
    var posterPath: String?
    var backdropPath: String?
    var status: String = "Returning Series"
    var firstAirDate: Date?
    var networks: String = ""
    var episodeRuntime: Int = 45
    var inLibrary: Bool = true
    var dateAdded: Date = Date()
    var lastUpdated: Date = Date()
    var voteAverage: Double = 0
    var originalLanguage: String = "en"
    var watchProgress: Double = 0
    var cachedAiredCount: Int = 0
    var cachedWatchedAiredCount: Int = 0
    var cachedWatchedCount: Int = 0
    var cachedStatusLine: String = ""
    var cachedIsCompleted: Bool = false
    var cachedIsWatching: Bool = false
    var cachedHasUpcoming: Bool = false
    var cachedHasUnwatchedAired: Bool = false
    var cachedNextAirDate: Date?
    var cachedNextUnwatchedCode: String = ""
    var cachedNextUnwatchedName: String = ""
    var cachedNextUnwatchedSeason: Int = 0
    var cachedLastWatchedAt: Date?
    var cachedWatchedMinutes: Int = 0
    var cachedEpisodeCount: Int = 0
    var cachedSeasonCount: Int = 0
    var cachedAirBeatsJSON: String = ""
    var cachedGenreNames: String = ""
    var watchCacheVersion: Int = 0
    var watchCacheBuilt: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Season.show)
    var seasons: [Season] = []

    @Relationship(inverse: \Genre.shows)
    var genres: [Genre] = []

    init(
        tmdbID: Int,
        name: String,
        overview: String = "",
        posterPath: String? = nil,
        backdropPath: String? = nil,
        status: String = "Returning Series",
        firstAirDate: Date? = nil,
        networks: String = "",
        episodeRuntime: Int = 45,
        inLibrary: Bool = true,
        dateAdded: Date = .now,
        lastUpdated: Date = .now,
        voteAverage: Double = 0,
        originalLanguage: String = "en",
        seasons: [Season] = [],
        genres: [Genre] = []
    ) {
        self.tmdbID = tmdbID
        self.name = name
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.status = status
        self.firstAirDate = firstAirDate
        self.networks = networks
        self.episodeRuntime = episodeRuntime
        self.inLibrary = inLibrary
        self.dateAdded = dateAdded
        self.lastUpdated = lastUpdated
        self.voteAverage = voteAverage
        self.originalLanguage = originalLanguage
        self.seasons = seasons
        self.genres = genres
    }
}

struct CachedAirBeat: Codable {
    var t: Int
    var s: Int
    var e: Int
    var n: String
}

extension Show {
    static let currentWatchCacheVersion = 3

    var sortedSeasons: [Season] {
        seasons.sorted { $0.seasonNumber < $1.seasonNumber }
    }

    var allEpisodes: [Episode] {
        seasons.flatMap(\.episodes)
    }

    var airedCount: Int { cachedAiredCount }

    var watchedAiredCount: Int { cachedWatchedAiredCount }

    var watchedCount: Int { cachedWatchedCount }

    var libraryStatusLine: String {
        cachedStatusLine.isEmpty ? status : cachedStatusLine
    }

    var progress: Double { watchProgress }

    var progressPercent: Int {
        Int((watchProgress * 100).rounded())
    }

    var totalEpisodeCount: Int { cachedEpisodeCount }

    var hasUnwatchedAired: Bool { cachedHasUnwatchedAired }

    var isCompleted: Bool { cachedIsCompleted }

    var isWatching: Bool { cachedIsWatching }

    var hasUpcoming: Bool { cachedHasUpcoming }

    func rebuildWatchCache() {
        let today = Date().startOfDay
        var watched = 0
        var aired = 0
        var watchedAired = 0
        var minutes = 0
        var episodeCount = 0
        var nextUnaired: Episode?
        var nextUnwatchedAired: Episode?
        var lastWatchedAt: Date?
        var beats: [CachedAirBeat] = []

        for episode in allEpisodes {
            episodeCount += 1
            if episode.isWatched {
                watched += 1
                minutes += episode.effectiveRuntime
                if let watchedAt = episode.watchedAt, watchedAt > (lastWatchedAt ?? .distantPast) {
                    lastWatchedAt = watchedAt
                }
            }
            guard let airDate = episode.airDate else { continue }
            let day = airDate.startOfDay
            beats.append(
                CachedAirBeat(
                    t: Int(day.timeIntervalSince1970),
                    s: episode.season?.seasonNumber ?? 0,
                    e: episode.episodeNumber,
                    n: episode.name
                )
            )
            if day <= today {
                aired += 1
                if episode.isWatched {
                    watchedAired += 1
                } else if nextUnwatchedAired == nil || Episode.airOrder(episode, nextUnwatchedAired!) {
                    nextUnwatchedAired = episode
                }
            } else if nextUnaired == nil || day < (nextUnaired?.airDate ?? .distantFuture) {
                nextUnaired = episode
            }
        }

        cachedWatchedCount = watched
        cachedAiredCount = aired
        cachedWatchedAiredCount = watchedAired
        cachedWatchedMinutes = minutes
        cachedEpisodeCount = episodeCount
        cachedSeasonCount = seasons.count
        cachedGenreNames = genres.map(\.name).sorted().joined(separator: "\u{1E}")
        for season in seasons {
            season.rebuildWatchCache(today: today)
        }
        watchProgress = aired > 0 ? Double(watchedAired) / Double(aired) : 0
        cachedHasUpcoming = nextUnaired != nil
        cachedNextAirDate = nextUnaired?.airDate
        cachedHasUnwatchedAired = nextUnwatchedAired != nil
        cachedIsCompleted = aired > 0 && nextUnwatchedAired == nil && nextUnaired == nil
        cachedIsWatching = watched > 0 && !cachedIsCompleted
        cachedLastWatchedAt = lastWatchedAt
        cachedNextUnwatchedCode = nextUnwatchedAired?.code ?? ""
        cachedNextUnwatchedName = nextUnwatchedAired?.name ?? ""
        cachedNextUnwatchedSeason = nextUnwatchedAired?.season?.seasonNumber ?? 0

        if let nextUnwatchedAired {
            cachedStatusLine = "Up next \(nextUnwatchedAired.code)"
        } else if let nextUnaired {
            cachedStatusLine = "Next \(Formatters.episodeAirLabel(nextUnaired.airDate))"
        } else if cachedIsCompleted {
            cachedStatusLine = "Completed"
        } else {
            cachedStatusLine = status
        }
        if let data = try? JSONEncoder().encode(beats),
           let json = String(data: data, encoding: .utf8) {
            cachedAirBeatsJSON = json
        } else {
            cachedAirBeatsJSON = "[]"
        }
        watchCacheVersion = Self.currentWatchCacheVersion
        watchCacheBuilt = true
    }

    func applyEpisodeWatchChange(_ episode: Episode, wasWatched: Bool, isWatched: Bool, today: Date = Date().startOfDay) {
        guard wasWatched != isWatched else { return }
        let runtime = episode.effectiveRuntime
        let aired = episode.airDate.map { $0.startOfDay <= today } ?? false

        if isWatched {
            cachedWatchedCount += 1
            cachedWatchedMinutes += runtime
            cachedLastWatchedAt = .now
            if aired {
                cachedWatchedAiredCount += 1
                watchProgress = cachedAiredCount > 0 ? Double(cachedWatchedAiredCount) / Double(cachedAiredCount) : 0
            }
        } else {
            cachedWatchedCount = max(0, cachedWatchedCount - 1)
            cachedWatchedMinutes = max(0, cachedWatchedMinutes - runtime)
            if aired {
                cachedWatchedAiredCount = max(0, cachedWatchedAiredCount - 1)
                watchProgress = cachedAiredCount > 0 ? Double(cachedWatchedAiredCount) / Double(cachedAiredCount) : 0
            }
        }

        if let season = episode.season {
            season.applyEpisodeWatchChange(episode, wasWatched: wasWatched, isWatched: isWatched, today: today)
        }

        rebuildNextUnwatchedFields(today: today)

        if !watchCacheBuilt {
            rebuildWatchCache()
        }
    }

    func rebuildNextUnwatchedFields(today: Date = Date().startOfDay) {
        var nextUnwatchedAired: Episode?
        var nextUnaired: Episode?

        for episode in allEpisodes {
            guard let airDate = episode.airDate else { continue }
            let day = airDate.startOfDay
            if day <= today {
                if !episode.isWatched && (nextUnwatchedAired == nil || Episode.airOrder(episode, nextUnwatchedAired!)) {
                    nextUnwatchedAired = episode
                }
            } else if nextUnaired == nil || day < (nextUnaired?.airDate ?? .distantFuture) {
                nextUnaired = episode
            }
        }

        cachedHasUnwatchedAired = nextUnwatchedAired != nil
        cachedHasUpcoming = nextUnaired != nil
        cachedNextAirDate = nextUnaired?.airDate
        cachedNextUnwatchedCode = nextUnwatchedAired?.code ?? ""
        cachedNextUnwatchedName = nextUnwatchedAired?.name ?? ""
        cachedNextUnwatchedSeason = nextUnwatchedAired?.season?.seasonNumber ?? 0
        cachedIsCompleted = cachedAiredCount > 0 && nextUnwatchedAired == nil && nextUnaired == nil
        cachedIsWatching = cachedWatchedCount > 0 && !cachedIsCompleted

        if let nextUnwatchedAired {
            cachedStatusLine = "Up next \(nextUnwatchedAired.code)"
        } else if let nextUnaired {
            cachedStatusLine = "Next \(Formatters.episodeAirLabel(nextUnaired.airDate))"
        } else if cachedIsCompleted {
            cachedStatusLine = "Completed"
        } else {
            cachedStatusLine = status
        }
    }

    var genreNames: [String] {
        if cachedGenreNames.isEmpty {
            return genres.map(\.name).sorted()
        }
        return cachedGenreNames.split(separator: "\u{1E}", omittingEmptySubsequences: false).map(String.init)
    }

    var yearLabel: String {
        guard let firstAirDate else { return "" }
        return Formatters.year.string(from: firstAirDate)
    }
}
