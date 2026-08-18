import Foundation

enum TMDBError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case invalidURL
    case http(Int)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add a TMDB API key in Settings to search shows."
        case .invalidAPIKey:
            return "That TMDB API key was rejected. Check that you pasted the API Key (v3)."
        case .invalidURL:
            return "The TMDB request URL was invalid."
        case .http(let code):
            return "TMDB returned HTTP \(code)."
        case .decoding:
            return "Could not read the TMDB response."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

actor TMDBService {
    static let shared = TMDBService()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 20
            configuration.urlCache = URLCache(
                memoryCapacity: 8 * 1_024 * 1_024,
                diskCapacity: 32 * 1_024 * 1_024,
                diskPath: "showPirate.tmdb"
            )
            configuration.requestCachePolicy = .useProtocolCachePolicy
            self.session = URLSession(configuration: configuration)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func searchTV(query: String, page: Int = 1) async throws -> [TMDBSearchShow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let response: TMDBPagedResponse<TMDBSearchShow> = try await get(
            path: "/search/tv",
            query: [
                "query": trimmed,
                "include_adult": "false",
                "page": String(page)
            ]
        )
        return response.results
    }

    func trendingTV() async throws -> [TMDBSearchShow] {
        let response: TMDBPagedResponse<TMDBSearchShow> = try await get(path: "/trending/tv/week", query: [:])
        return response.results
    }

    func popularTV() async throws -> [TMDBSearchShow] {
        let response: TMDBPagedResponse<TMDBSearchShow> = try await get(path: "/tv/popular", query: [:])
        return response.results
    }

    func onTheAirTV() async throws -> [TMDBSearchShow] {
        let response: TMDBPagedResponse<TMDBSearchShow> = try await get(path: "/tv/on_the_air", query: [:])
        return response.results
    }

    func fetchCredits(showID: Int) async throws -> TMDBCredits {
        try await get(path: "/tv/\(showID)/credits", query: [:])
    }

    func fetchWatchProviders(showID: Int) async throws -> TMDBWatchProviderRegion? {
        let response: TMDBWatchProvidersResponse = try await get(
            path: "/tv/\(showID)/watch/providers",
            query: [:]
        )
        let region = Locale.current.region?.identifier ?? "US"
        return response.results?[region] ?? response.results?["US"]
    }

    func fetchShowDetails(id: Int) async throws -> TMDBShowDetails {
        try await get(path: "/tv/\(id)", query: [:])
    }

    func fetchSeason(showID: Int, seasonNumber: Int) async throws -> TMDBSeasonDetails {
        try await get(path: "/tv/\(showID)/season/\(seasonNumber)", query: [:])
    }

    func fetchShowWithSeasons(id: Int) async throws -> (TMDBShowDetails, [TMDBSeasonDetails]) {
        let details = try await fetchShowDetails(id: id)
        let seasonNumbers = (details.seasons ?? [])
            .map(\.seasonNumber)
            .filter { $0 > 0 }

        var seasons: [TMDBSeasonDetails] = []
        seasons.reserveCapacity(seasonNumbers.count)

        try await withThrowingTaskGroup(of: TMDBSeasonDetails.self) { group in
            for number in seasonNumbers {
                group.addTask {
                    try await self.fetchSeason(showID: id, seasonNumber: number)
                }
            }
            for try await season in group {
                seasons.append(season)
            }
        }

        seasons.sort { $0.seasonNumber < $1.seasonNumber }
        return (details, seasons)
    }

    func validateAPIKey(_ key: String) async throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TMDBError.missingAPIKey }

        guard var components = URLComponents(string: APIConfig.tmdbBaseURL.absoluteString + "/configuration") else {
            throw TMDBError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "api_key", value: trimmed)]
        guard let url = components.url else { throw TMDBError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TMDBError.http(-1)
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                throw TMDBError.invalidAPIKey
            }
            guard (200...299).contains(http.statusCode) else {
                throw TMDBError.http(http.statusCode)
            }
        } catch let error as TMDBError {
            throw error
        } catch {
            throw TMDBError.transport(error)
        }
    }

    private func get<T: Decodable>(path: String, query: [String: String]) async throws -> T {
        guard APIConfig.hasAPIKey else { throw TMDBError.missingAPIKey }

        let pathSuffix = path.hasPrefix("/") ? path : "/\(path)"
        guard var components = URLComponents(string: APIConfig.tmdbBaseURL.absoluteString + pathSuffix) else {
            throw TMDBError.invalidURL
        }

        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "language", value: "en-US"))

        items.append(URLQueryItem(name: "api_key", value: APIConfig.apiKey))
        components.queryItems = items

        guard let url = components.url else { throw TMDBError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw TMDBError.http(http.statusCode)
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw TMDBError.decoding(error)
            }
        } catch let error as TMDBError {
            throw error
        } catch {
            throw TMDBError.transport(error)
        }
    }
}
