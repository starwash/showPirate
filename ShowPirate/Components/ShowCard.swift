import SwiftUI

struct ShowCard: View {
    let show: Show
    var width: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                PosterView(path: show.posterPath, width: width)
                WatchProgressBar(progress: show.progress)
                    .padding(8)
            }
            .frame(width: width, height: width / Theme.posterAspect)

            VStack(alignment: .leading, spacing: 2) {
                Text(show.name)
                    .font(.headline)
                    .foregroundStyle(Theme.cream)
                    .lineLimit(1)
                Text(show.libraryStatusLine)
                    .font(.caption)
                    .foregroundStyle(Theme.parchment.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(width: width, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}

struct ShowListRow: View {
    let show: Show
    var height: CGFloat = 148

    var body: some View {
        ZStack(alignment: .bottom) {
            BannerView(
                path: show.backdropPath ?? show.posterPath,
                height: height,
                size: .poster
            )

            LinearGradient(
                colors: [
                    .black.opacity(0.05),
                    .black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(show.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.cream)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(show.progressPercent)%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.watchedGreen)
                }

                Text(show.libraryStatusLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.parchment.opacity(0.9))
                    .lineLimit(1)

                WatchProgressBar(progress: show.progress, height: 8)

                    Text("\(show.watchedAiredCount) of \(show.airedCount) aired episodes watched")
                        .font(.caption)
                        .foregroundStyle(Theme.parchment.opacity(0.85))
            }
            .padding(16)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.huntGray.opacity(0.22), lineWidth: 1)
        }
        .pirateCardShadow()
        .contentShape(Rectangle())
    }
}

struct ContinueWatchingCard: View {
    let show: Show

    var body: some View {
        GlassCard(padding: 12) {
            HStack(alignment: .top, spacing: 14) {
                PosterView(path: show.posterPath, size: .posterSmall, width: 72)
                VStack(alignment: .leading, spacing: 8) {
                    Text(show.name)
                        .font(.headline)
                        .foregroundStyle(Theme.cream)
                    if !show.cachedNextUnwatchedCode.isEmpty {
                        Text("Continue \(show.cachedNextUnwatchedCode) · \(show.cachedNextUnwatchedName)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.parchment.opacity(0.75))
                            .lineLimit(2)
                    }
                    WatchProgressBar(progress: show.progress)
                    Text("\(show.progressPercent)% watched")
                        .font(.caption)
                        .foregroundStyle(Theme.cyan)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct UpcomingEpisodeCard: View {
    let episode: Episode

    var body: some View {
        CachedUpcomingEpisodeCard(
            item: CalendarDayItem(
                showID: episode.season?.show?.tmdbID ?? 0,
                showName: episode.showName,
                posterPath: episode.season?.show?.posterPath,
                season: episode.season?.seasonNumber ?? 0,
                episode: episode.episodeNumber,
                name: episode.name,
                airDate: episode.airDate ?? .distantPast
            )
        )
    }
}

struct CachedUpcomingEpisodeCard: View {
    let item: CalendarDayItem

    var body: some View {
        GlassCard(padding: 12) {
            HStack(spacing: 12) {
                PosterView(path: item.posterPath, size: .posterSmall, width: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.showName)
                        .font(.headline)
                        .foregroundStyle(Theme.cream)
                        .lineLimit(1)
                    Text("\(item.code) · \(item.name)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.parchment.opacity(0.75))
                        .lineLimit(1)
                    Text(Formatters.episodeAirLabel(item.airDate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.isAiringToday ? Theme.crimson : Theme.cyan)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
