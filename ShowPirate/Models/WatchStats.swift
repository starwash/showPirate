import Foundation

struct WatchStats: Equatable {
    var watchedEpisodes: Int
    var watchedShows: Int
    var showsInLibrary: Int
    var minutesWatched: Int
    var genreCounts: [(name: String, count: Int)]

    var hoursWatched: Double {
        Double(minutesWatched) / 60.0
    }

    var timeWatchedLabel: String {
        Formatters.watchTime(minutes: minutesWatched)
    }

    var favouriteGenres: [(name: String, count: Int)] {
        Array(genreCounts.prefix(6))
    }

    static let empty = WatchStats(
        watchedEpisodes: 0,
        watchedShows: 0,
        showsInLibrary: 0,
        minutesWatched: 0,
        genreCounts: []
    )
}

extension WatchStats {
    static func == (lhs: WatchStats, rhs: WatchStats) -> Bool {
        lhs.watchedEpisodes == rhs.watchedEpisodes
            && lhs.watchedShows == rhs.watchedShows
            && lhs.showsInLibrary == rhs.showsInLibrary
            && lhs.minutesWatched == rhs.minutesWatched
            && lhs.genreCounts.map(\.name) == rhs.genreCounts.map(\.name)
            && lhs.genreCounts.map(\.count) == rhs.genreCounts.map(\.count)
    }
}
