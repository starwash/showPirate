import Foundation

enum StatisticsService {
    static func stats(for shows: [Show]) -> WatchStats {
        let library = shows.filter(\.inLibrary)
        var watchedEpisodes = 0
        var minutes = 0
        var completedShows = 0
        var genreTally: [String: Int] = [:]

        for show in library {
            watchedEpisodes += show.cachedWatchedCount
            minutes += show.cachedWatchedMinutes
            if show.isCompleted { completedShows += 1 }
            if show.cachedWatchedCount > 0 {
                for genre in show.genreNames {
                    genreTally[genre, default: 0] += show.cachedWatchedCount
                }
            }
        }

        let ranked = genreTally
            .map { (name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.name < $1.name }
                return $0.count > $1.count
            }

        return WatchStats(
            watchedEpisodes: watchedEpisodes,
            watchedShows: completedShows,
            showsInLibrary: library.count,
            minutesWatched: minutes,
            genreCounts: ranked
        )
    }
}
