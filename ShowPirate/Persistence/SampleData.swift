import Foundation
import SwiftData

enum SampleData {
    static func seedIfNeeded(in context: ModelContext) {
        var descriptor = FetchDescriptor<Show>()
        descriptor.fetchLimit = 1
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        seed(in: context, force: false)
        try? context.save()
    }

    static func seed(in context: ModelContext, force: Bool) {
        if !force {
            var descriptor = FetchDescriptor<Show>()
            descriptor.fetchLimit = 1
            if !((try? context.fetch(descriptor)) ?? []).isEmpty { return }
        }

        let drama = Genre(tmdbID: 18, name: "Drama")
        let comedy = Genre(tmdbID: 35, name: "Comedy")
        let crime = Genre(tmdbID: 80, name: "Crime")
        let sciFi = Genre(tmdbID: 10765, name: "Sci-Fi & Fantasy")
        let mystery = Genre(tmdbID: 9648, name: "Mystery")
        let action = Genre(tmdbID: 10759, name: "Action & Adventure")
        let warPolitics = Genre(tmdbID: 10768, name: "War & Politics")

        for genre in [drama, comedy, crime, sciFi, mystery, action, warPolitics] {
            context.insert(genre)
        }

        let calendar = Calendar.current
        let today = Date().startOfDay

        func date(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        func year(_ value: Int) -> Date {
            var components = DateComponents()
            components.year = value
            components.month = 1
            components.day = 20
            return calendar.date(from: components) ?? today
        }

        // Continue watching: mid-progress, next unwatched has already aired.
        insertShow(
            in: context,
            tmdbID: 1396,
            name: "Breaking Bad",
            overview: "A struggling chemistry teacher turns to a life of crime, producing and selling methamphetamine with a former student.",
            posterPath: "/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg",
            backdropPath: "/tsRy63Mu5cu8etL1X7ZLyowYTWX.jpg",
            status: "Ended",
            firstAirDate: year(2008),
            networks: "AMC",
            runtime: 47,
            voteAverage: 8.9,
            genres: [drama, crime],
            seasons: [
                seasonSpec(1, episodes: 7, start: date(-420), watchedThrough: 7, runtime: 47),
                seasonSpec(2, episodes: 13, start: date(-360), watchedThrough: 4, runtime: 47)
            ]
        )

        insertShow(
            in: context,
            tmdbID: 2316,
            name: "The Office",
            overview: "A mockumentary on a group of typical office workers, where the workday consists of ego clashes, inappropriate behavior, and tedium.",
            posterPath: "/7DJKHzAi83BmQrWLrYYOqcoKfhR.jpg",
            backdropPath: "/mLyW3UTgi2lsMdtueYODcfAB9Ku.jpg",
            status: "Ended",
            firstAirDate: year(2005),
            networks: "NBC",
            runtime: 22,
            voteAverage: 8.5,
            genres: [comedy],
            seasons: [
                seasonSpec(1, episodes: 6, start: date(-900), watchedThrough: 6, runtime: 22),
                seasonSpec(2, episodes: 22, start: date(-800), watchedThrough: 10, runtime: 22)
            ]
        )

        // Upcoming + continue watching hybrid.
        insertShow(
            in: context,
            tmdbID: 95396,
            name: "Severance",
            overview: "Mark leads a team of office workers whose memories have been surgically divided between their work and personal lives.",
            posterPath: "/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg",
            backdropPath: "/5lAMQMWpXSwvMFBqH3dZ4bcdA4g.jpg",
            status: "Returning Series",
            firstAirDate: year(2022),
            networks: "Apple TV+",
            runtime: 52,
            voteAverage: 8.4,
            genres: [drama, mystery, sciFi],
            seasons: [
                seasonSpec(1, episodes: 9, start: date(-400), watchedThrough: 9, runtime: 52),
                SeasonBuild(
                    number: 2,
                    episodeCount: 10,
                    startOffset: -21,
                    watchedThrough: 6,
                    runtime: 52,
                    cadence: 7
                )
            ]
        )

        insertShow(
            in: context,
            tmdbID: 136315,
            name: "The Bear",
            overview: "A young chef from the fine dining world returns to Chicago to run his family's sandwich shop.",
            posterPath: "/6FVNnVk0SZFdzb9dkvOr13XyyM4.jpg",
            backdropPath: "/9n2tJBplPbgRFhm7jJkcUn4QP9B.jpg",
            status: "Returning Series",
            firstAirDate: year(2022),
            networks: "FX",
            runtime: 30,
            voteAverage: 8.3,
            genres: [drama, comedy],
            seasons: [
                seasonSpec(1, episodes: 8, start: date(-500), watchedThrough: 8, runtime: 30),
                seasonSpec(2, episodes: 10, start: date(-200), watchedThrough: 7, runtime: 30)
            ]
        )

        insertShow(
            in: context,
            tmdbID: 100088,
            name: "The Last of Us",
            overview: "Joel and Ellie, a pair connected through the harshness of the world they live in, are forced to endure brutal circumstances together.",
            posterPath: "/dmo6TYuuJgaYinXBPjrgG9mB5od.jpg",
            backdropPath: "/uDgy6GRgzc1rnfWlbXsU6JRnR6f.jpg",
            status: "Returning Series",
            firstAirDate: year(2023),
            networks: "HBO",
            runtime: 55,
            voteAverage: 8.6,
            genres: [drama, action, sciFi],
            seasons: [
                seasonSpec(1, episodes: 9, start: date(-550), watchedThrough: 9, runtime: 55),
                SeasonBuild(
                    number: 2,
                    episodeCount: 7,
                    startOffset: -28,
                    watchedThrough: 3,
                    runtime: 55,
                    cadence: 7
                )
            ]
        )

        insertShow(
            in: context,
            tmdbID: 76331,
            name: "Succession",
            overview: "The Roy family is known for controlling the biggest media and entertainment company in the world. Follow their lives as they contemplate their future.",
            posterPath: "/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg",
            backdropPath: "/6t6r1VG5qZpcIXuLcJlqH5p0p5N.jpg",
            status: "Ended",
            firstAirDate: year(2018),
            networks: "HBO",
            runtime: 60,
            voteAverage: 8.5,
            genres: [drama, warPolitics],
            seasons: [
                seasonSpec(1, episodes: 10, start: date(-1100), watchedThrough: 10, runtime: 60),
                seasonSpec(2, episodes: 10, start: date(-900), watchedThrough: 10, runtime: 60)
            ]
        )

        insertShow(
            in: context,
            tmdbID: 97546,
            name: "Ted Lasso",
            overview: "American football coach Ted Lasso heads to London to manage AFC Richmond, a struggling soccer team, despite having no experience.",
            posterPath: "/uRHsiw1wLxPHFXkkv4Ix1s0O6f4.jpg",
            backdropPath: "/rQGBjWNveYoIYSmW4tARfAkIf1F.jpg",
            status: "Ended",
            firstAirDate: year(2020),
            networks: "Apple TV+",
            runtime: 30,
            voteAverage: 8.4,
            genres: [comedy, drama],
            seasons: [
                seasonSpec(1, episodes: 10, start: date(-700), watchedThrough: 10, runtime: 30),
                seasonSpec(2, episodes: 12, start: date(-500), watchedThrough: 12, runtime: 30)
            ]
        )

        insertShow(
            in: context,
            tmdbID: 66732,
            name: "Stranger Things",
            overview: "When a young boy vanishes, a small town uncovers a mystery involving secret experiments, terrifying supernatural forces, and one strange little girl.",
            posterPath: "/uOOtwVbSr4QDjAGIifLDwpb2Pdl.jpg",
            backdropPath: "/56v2KjBlU4XaOv9rVYEQypROD7P.jpg",
            status: "Returning Series",
            firstAirDate: year(2016),
            networks: "Netflix",
            runtime: 50,
            voteAverage: 8.6,
            genres: [drama, sciFi, mystery],
            seasons: [
                seasonSpec(1, episodes: 8, start: date(-1200), watchedThrough: 8, runtime: 50),
                SeasonBuild(
                    number: 5,
                    episodeCount: 8,
                    startOffset: -3,
                    watchedThrough: 1,
                    runtime: 70,
                    cadence: 7
                )
            ]
        )
    }

    private struct SeasonBuild {
        var number: Int
        var episodeCount: Int
        var startOffset: Int
        var watchedThrough: Int
        var runtime: Int
        var cadence: Int = 7
    }

    private static func seasonSpec(
        _ number: Int,
        episodes: Int,
        start: Date,
        watchedThrough: Int,
        runtime: Int
    ) -> SeasonBuild {
        let offset = Calendar.current.dateComponents([.day], from: Date().startOfDay, to: start.startOfDay).day ?? -30
        return SeasonBuild(
            number: number,
            episodeCount: episodes,
            startOffset: offset,
            watchedThrough: watchedThrough,
            runtime: runtime
        )
    }

    private static func insertShow(
        in context: ModelContext,
        tmdbID: Int,
        name: String,
        overview: String,
        posterPath: String,
        backdropPath: String,
        status: String,
        firstAirDate: Date,
        networks: String,
        runtime: Int,
        voteAverage: Double,
        genres: [Genre],
        seasons: [SeasonBuild]
    ) {
        let show = Show(
            tmdbID: tmdbID,
            name: name,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            status: status,
            firstAirDate: firstAirDate,
            networks: networks,
            episodeRuntime: runtime,
            inLibrary: true,
            voteAverage: voteAverage
        )
        show.genres = genres

        let calendar = Calendar.current
        let today = Date().startOfDay

        for spec in seasons {
            let season = Season(
                tmdbID: tmdbID * 100 + spec.number,
                seasonNumber: spec.number,
                name: "Season \(spec.number)",
                episodeCount: spec.episodeCount,
                show: show
            )

            for index in 1...spec.episodeCount {
                let offset = spec.startOffset + ((index - 1) * spec.cadence)
                let airDate = calendar.date(byAdding: .day, value: offset, to: today)
                let watched = index <= spec.watchedThrough
                let episode = Episode(
                    tmdbID: tmdbID * 10_000 + spec.number * 100 + index,
                    episodeNumber: index,
                    name: episodeTitle(show: name, season: spec.number, episode: index),
                    overview: "Episode \(index) of \(name), season \(spec.number).",
                    airDate: airDate,
                    runtime: spec.runtime,
                    isWatched: watched,
                    watchedAt: watched ? airDate : nil,
                    season: season
                )
                season.episodes.append(episode)
            }
            show.seasons.append(season)
        }

        context.insert(show)
    }

    private static func episodeTitle(show: String, season: Int, episode: Int) -> String {
        let titles: [String: [Int: [String]]] = [
            "Breaking Bad": [
                1: ["Pilot", "Cat's in the Bag...", "...And the Bag's in the River", "Cancer Man", "Gray Matter", "Crazy Handful of Nothin'", "A No-Rough-Stuff-Type Deal"],
                2: ["Seven Thirty-Seven", "Grilled", "Bit by a Dead Bee", "Down", "Breakage", "Peekaboo", "Negro y Azul", "Better Call Saul", "4 Days Out", "Over", "Mandala", "Phoenix", "ABQ"]
            ],
            "The Office": [
                1: ["Pilot", "Diversity Day", "Health Care", "The Alliance", "Basketball", "Hot Girl"]
            ],
            "Severance": [
                1: ["Good News About Hell", "Half Loop", "In Perpetuity", "The You You Are", "The Grim Barbarity of Optics and Design", "Hide and Seek", "Defiant Jazz", "What's for Dinner?", "The We We Are"]
            ]
        ]
        if let title = titles[show]?[season]?[safe: episode - 1] {
            return title
        }
        return "Episode \(episode)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
