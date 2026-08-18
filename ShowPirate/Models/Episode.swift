import Foundation
import SwiftData

@Model
final class Episode {
    var tmdbID: Int = 0
    var episodeNumber: Int = 0
    var name: String = ""
    var overview: String = ""
    var airDate: Date?
    var runtime: Int = 0
    var stillPath: String?
    var voteAverage: Double = 0
    var isWatched: Bool = false
    var watchedAt: Date?

    var season: Season?

    init(
        tmdbID: Int,
        episodeNumber: Int,
        name: String,
        overview: String = "",
        airDate: Date? = nil,
        runtime: Int = 0,
        stillPath: String? = nil,
        voteAverage: Double = 0,
        isWatched: Bool = false,
        watchedAt: Date? = nil,
        season: Season? = nil
    ) {
        self.tmdbID = tmdbID
        self.episodeNumber = episodeNumber
        self.name = name
        self.overview = overview
        self.airDate = airDate
        self.runtime = runtime
        self.stillPath = stillPath
        self.voteAverage = voteAverage
        self.isWatched = isWatched
        self.watchedAt = watchedAt
        self.season = season
    }
}

extension Episode {
    var hasAired: Bool {
        guard let airDate else { return false }
        return airDate.startOfDay <= Date().startOfDay
    }

    var isAiringToday: Bool {
        guard let airDate else { return false }
        return Calendar.current.isDateInToday(airDate)
    }

    var code: String {
        let seasonNumber = season?.seasonNumber ?? 0
        return String(format: "S%02dE%02d", seasonNumber, episodeNumber)
    }

    var showName: String {
        season?.show?.name ?? ""
    }

    var effectiveRuntime: Int {
        if runtime > 0 { return runtime }
        return season?.show?.episodeRuntime ?? 0
    }

    static func airOrder(_ lhs: Episode, _ rhs: Episode) -> Bool {
        let left = (lhs.season?.seasonNumber ?? 0, lhs.episodeNumber)
        let right = (rhs.season?.seasonNumber ?? 0, rhs.episodeNumber)
        return left < right
    }
}
