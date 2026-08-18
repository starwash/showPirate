import Foundation
import SwiftData

struct CatalogFile: Codable {
    var formatVersion: Int
    var exportedAt: Date
    var shows: [CatalogShow]

    static let currentFormatVersion = 1
}

struct CatalogShow: Codable {
    var tmdbID: Int
    var name: String
    var overview: String
    var posterPath: String?
    var backdropPath: String?
    var status: String
    var firstAirDate: Date?
    var networks: String
    var episodeRuntime: Int
    var inLibrary: Bool
    var dateAdded: Date
    var lastUpdated: Date
    var voteAverage: Double
    var originalLanguage: String
    var genres: [CatalogGenre]
    var seasons: [CatalogSeason]
}

struct CatalogGenre: Codable {
    var tmdbID: Int
    var name: String
}

struct CatalogSeason: Codable {
    var tmdbID: Int
    var seasonNumber: Int
    var name: String
    var overview: String
    var posterPath: String?
    var episodeCount: Int
    var airDate: Date?
    var episodes: [CatalogEpisode]
}

struct CatalogEpisode: Codable {
    var tmdbID: Int
    var episodeNumber: Int
    var name: String
    var overview: String
    var airDate: Date?
    var runtime: Int
    var stillPath: String?
    var voteAverage: Double
    var isWatched: Bool
    var watchedAt: Date?
}

enum CatalogCodec {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func makeCatalog(from shows: [Show], exportedAt: Date = .now) -> CatalogFile {
        CatalogFile(
            formatVersion: CatalogFile.currentFormatVersion,
            exportedAt: exportedAt,
            shows: shows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map(encode)
        )
    }

    static func encode(_ show: Show) -> CatalogShow {
        CatalogShow(
            tmdbID: show.tmdbID,
            name: show.name,
            overview: show.overview,
            posterPath: show.posterPath,
            backdropPath: show.backdropPath,
            status: show.status,
            firstAirDate: show.firstAirDate,
            networks: show.networks,
            episodeRuntime: show.episodeRuntime,
            inLibrary: show.inLibrary,
            dateAdded: show.dateAdded,
            lastUpdated: show.lastUpdated,
            voteAverage: show.voteAverage,
            originalLanguage: show.originalLanguage,
            genres: show.genres
                .sorted { $0.name < $1.name }
                .map { CatalogGenre(tmdbID: $0.tmdbID, name: $0.name) },
            seasons: show.sortedSeasons.map(encode)
        )
    }

    static func encode(_ season: Season) -> CatalogSeason {
        CatalogSeason(
            tmdbID: season.tmdbID,
            seasonNumber: season.seasonNumber,
            name: season.name,
            overview: season.overview,
            posterPath: season.posterPath,
            episodeCount: season.episodeCount,
            airDate: season.airDate,
            episodes: season.sortedEpisodes.map(encode)
        )
    }

    static func encode(_ episode: Episode) -> CatalogEpisode {
        CatalogEpisode(
            tmdbID: episode.tmdbID,
            episodeNumber: episode.episodeNumber,
            name: episode.name,
            overview: episode.overview,
            airDate: episode.airDate,
            runtime: episode.runtime,
            stillPath: episode.stillPath,
            voteAverage: episode.voteAverage,
            isWatched: episode.isWatched,
            watchedAt: episode.watchedAt
        )
    }
}
