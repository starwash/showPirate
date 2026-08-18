import Foundation

struct TMDBPagedResponse<T: Decodable>: Decodable {
    let page: Int
    let results: [T]
    let totalPages: Int
    let totalResults: Int
}

struct TMDBSearchShow: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let originCountry: [String]?
    let genreIDs: [Int]?
    let popularity: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, popularity
        case originalName
        case posterPath
        case backdropPath
        case firstAirDate
        case voteAverage
        case originCountry
        case genreIDs = "genreIds"
    }

    var yearLabel: String {
        guard let firstAirDate, firstAirDate.count >= 4 else { return "" }
        return String(firstAirDate.prefix(4))
    }
}

struct TMDBGenre: Decodable, Hashable {
    let id: Int
    let name: String
}

struct TMDBNetwork: Decodable, Hashable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String?
}

struct TMDBSeasonSummary: Decodable, Hashable {
    let id: Int
    let name: String
    let overview: String?
    let seasonNumber: Int
    let episodeCount: Int?
    let airDate: String?
    let posterPath: String?
}

struct TMDBShowDetails: Decodable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    let lastAirDate: String?
    let status: String?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let episodeRunTime: [Int]?
    let voteAverage: Double?
    let originalLanguage: String?
    let genres: [TMDBGenre]?
    let networks: [TMDBNetwork]?
    let seasons: [TMDBSeasonSummary]?
    let inProduction: Bool?
}

struct TMDBSeasonDetails: Decodable {
    let id: Int
    let name: String
    let overview: String?
    let seasonNumber: Int
    let airDate: String?
    let posterPath: String?
    let episodes: [TMDBEpisode]?
}

struct TMDBEpisode: Decodable, Identifiable {
    let id: Int
    let name: String?
    let overview: String?
    let episodeNumber: Int
    let seasonNumber: Int?
    let airDate: String?
    let runtime: Int?
    let stillPath: String?
    let voteAverage: Double?
}

struct TMDBCredits: Decodable {
    let cast: [TMDBCastMember]
    let crew: [TMDBCrewMember]
}

struct TMDBCastMember: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?
}

struct TMDBCrewMember: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?

    var stableID: String { "\(id)-\(job ?? department ?? name)" }
}

struct TMDBWatchProvidersResponse: Decodable {
    let results: [String: TMDBWatchProviderRegion]?
}

struct TMDBWatchProviderRegion: Decodable {
    let link: String?
    let flatrate: [TMDBWatchProvider]?
    let ads: [TMDBWatchProvider]?
    let buy: [TMDBWatchProvider]?
    let rent: [TMDBWatchProvider]?

    var streaming: [TMDBWatchProvider] {
        let combined = (flatrate ?? []) + (ads ?? [])
        var seen: Set<Int> = []
        return combined.filter { seen.insert($0.providerId).inserted }
            .sorted { ($0.displayPriority ?? 100) < ($1.displayPriority ?? 100) }
    }
}

struct TMDBWatchProvider: Decodable, Identifiable, Hashable {
    var id: Int { providerId }
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int?
}
