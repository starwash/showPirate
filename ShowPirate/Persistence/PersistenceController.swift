import Foundation
import SwiftData

enum PersistenceController {
    static let legacyStoreName = "showPirate.library"
    static let cloudStoreName = "showPirate.library.icloud"
    static let localStoreName = "showPirate.library.local"
    static let migratedKey = "showPirate.didMigrateLocalLibraryToCloud"

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Show.self, Season.self, Episode.self, Genre.self])
        let localConfig = ModelConfiguration(
            localStoreName,
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [localConfig])
            migrateIfNeeded(into: container, from: cloudStoreName)
            migrateIfNeeded(into: container, from: legacyStoreName)
            return container
        } catch {
            assertionFailure("Failed to create ModelContainer: \(error)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    private static func migrateIfNeeded(into destination: ModelContainer, from storeName: String) {
        let defaults = UserDefaults.standard
        let flag = "\(migratedKey).\(storeName)"
        guard defaults.bool(forKey: flag) == false else { return }

        let schema = Schema([Show.self, Season.self, Episode.self, Genre.self])
        let sourceConfig = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        guard let sourceContainer = try? ModelContainer(for: schema, configurations: [sourceConfig]) else {
            defaults.set(true, forKey: flag)
            return
        }

        let source = ModelContext(sourceContainer)
        let dest = ModelContext(destination)
        let destinationShows = (try? dest.fetch(FetchDescriptor<Show>())) ?? []
        if !destinationShows.isEmpty {
            defaults.set(true, forKey: flag)
            return
        }

        let sourceShows = (try? source.fetch(FetchDescriptor<Show>())) ?? []
        guard !sourceShows.isEmpty else {
            defaults.set(true, forKey: flag)
            return
        }

        var genreMap: [Int: Genre] = [:]

        func destinationGenre(tmdbID: Int, name: String) -> Genre {
            if let existing = genreMap[tmdbID] {
                return existing
            }
            var descriptor = FetchDescriptor<Genre>(
                predicate: #Predicate { $0.tmdbID == tmdbID }
            )
            descriptor.fetchLimit = 1
            if let existing = try? dest.fetch(descriptor).first {
                genreMap[tmdbID] = existing
                return existing
            }
            let genre = Genre(tmdbID: tmdbID, name: name)
            dest.insert(genre)
            genreMap[tmdbID] = genre
            return genre
        }

        for sourceShow in sourceShows {
            let show = Show(
                tmdbID: sourceShow.tmdbID,
                name: sourceShow.name,
                overview: sourceShow.overview,
                posterPath: sourceShow.posterPath,
                backdropPath: sourceShow.backdropPath,
                status: sourceShow.status,
                firstAirDate: sourceShow.firstAirDate,
                networks: sourceShow.networks,
                episodeRuntime: sourceShow.episodeRuntime,
                inLibrary: sourceShow.inLibrary,
                dateAdded: sourceShow.dateAdded,
                lastUpdated: sourceShow.lastUpdated,
                voteAverage: sourceShow.voteAverage,
                originalLanguage: sourceShow.originalLanguage
            )
            dest.insert(show)

            for sourceGenre in sourceShow.genres {
                let genre = destinationGenre(tmdbID: sourceGenre.tmdbID, name: sourceGenre.name)
                if !show.genres.contains(where: { $0.tmdbID == genre.tmdbID }) {
                    show.genres.append(genre)
                }
            }

            for sourceSeason in sourceShow.sortedSeasons {
                let season = Season(
                    tmdbID: sourceSeason.tmdbID,
                    seasonNumber: sourceSeason.seasonNumber,
                    name: sourceSeason.name,
                    overview: sourceSeason.overview,
                    posterPath: sourceSeason.posterPath,
                    episodeCount: sourceSeason.episodeCount,
                    airDate: sourceSeason.airDate,
                    show: show
                )
                for sourceEpisode in sourceSeason.sortedEpisodes {
                    let episode = Episode(
                        tmdbID: sourceEpisode.tmdbID,
                        episodeNumber: sourceEpisode.episodeNumber,
                        name: sourceEpisode.name,
                        overview: sourceEpisode.overview,
                        airDate: sourceEpisode.airDate,
                        runtime: sourceEpisode.runtime,
                        stillPath: sourceEpisode.stillPath,
                        isWatched: sourceEpisode.isWatched,
                        watchedAt: sourceEpisode.watchedAt,
                        season: season
                    )
                    season.episodes.append(episode)
                }
                show.seasons.append(season)
            }
            show.rebuildWatchCache()
        }

        try? dest.save()
        defaults.set(true, forKey: flag)
    }
}
