import Foundation
import SwiftData

@Model
final class Season {
    var tmdbID: Int = 0
    var seasonNumber: Int = 0
    var name: String = ""
    var overview: String = ""
    var posterPath: String?
    var episodeCount: Int = 0
    var airDate: Date?
    var cachedWatchedCount: Int = 0
    var cachedAiredCount: Int = 0
    var cachedWatchedAiredCount: Int = 0
    var cachedProgress: Double = 0
    var cachedIsFullyWatched: Bool = false

    var show: Show?

    @Relationship(deleteRule: .cascade, inverse: \Episode.season)
    var episodes: [Episode] = []

    init(
        tmdbID: Int,
        seasonNumber: Int,
        name: String,
        overview: String = "",
        posterPath: String? = nil,
        episodeCount: Int = 0,
        airDate: Date? = nil,
        show: Show? = nil,
        episodes: [Episode] = []
    ) {
        self.tmdbID = tmdbID
        self.seasonNumber = seasonNumber
        self.name = name
        self.overview = overview
        self.posterPath = posterPath
        self.episodeCount = episodeCount
        self.airDate = airDate
        self.show = show
        self.episodes = episodes
    }
}

extension Season {
    var sortedEpisodes: [Episode] {
        episodes.sorted { $0.episodeNumber < $1.episodeNumber }
    }

    var watchedCount: Int { cachedWatchedCount }

    var airedCount: Int { cachedAiredCount }

    var progress: Double { cachedProgress }

    var isFullyWatched: Bool { cachedIsFullyWatched }

    func rebuildWatchCache(today: Date) {
        var watched = 0
        var aired = 0
        var watchedAired = 0

        for episode in episodes {
            if episode.isWatched {
                watched += 1
            }
            if let airDate = episode.airDate, airDate.startOfDay <= today {
                aired += 1
                if episode.isWatched {
                    watchedAired += 1
                }
            }
        }

        cachedWatchedCount = watched
        cachedAiredCount = aired
        cachedWatchedAiredCount = watchedAired
        cachedProgress = aired > 0 ? Double(watchedAired) / Double(aired) : 0
        cachedIsFullyWatched = aired > 0 && watchedAired == aired
    }

    func applyEpisodeWatchChange(_ episode: Episode, wasWatched: Bool, isWatched: Bool, today: Date) {
        guard wasWatched != isWatched else { return }
        let aired = episode.airDate.map { $0.startOfDay <= today } ?? false

        if isWatched {
            cachedWatchedCount += 1
            if aired {
                cachedWatchedAiredCount += 1
            }
        } else {
            cachedWatchedCount = max(0, cachedWatchedCount - 1)
            if aired {
                cachedWatchedAiredCount = max(0, cachedWatchedAiredCount - 1)
            }
        }

        cachedProgress = cachedAiredCount > 0 ? Double(cachedWatchedAiredCount) / Double(cachedAiredCount) : 0
        cachedIsFullyWatched = cachedAiredCount > 0 && cachedWatchedAiredCount == cachedAiredCount
    }
}
