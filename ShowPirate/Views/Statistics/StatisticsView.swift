import SwiftUI

struct StatisticsView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        let stats = store.dashboardSnapshot.stats
        let maxGenre = stats.favouriteGenres.map(\.count).max() ?? 1
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Watch Statistics", subtitle: "Built from episodes you've marked watched.")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
                    StatTile(title: "Watched episodes", value: "\(stats.watchedEpisodes)", systemImage: "checkmark.circle", accent: Theme.huntRed)
                    StatTile(title: "Completed shows", value: "\(stats.watchedShows)", systemImage: "trophy", accent: Theme.huntTeal)
                    StatTile(title: "Shows in library", value: "\(stats.showsInLibrary)", systemImage: "rectangle.stack", accent: Theme.gold)
                    StatTile(title: "Time watched", value: stats.timeWatchedLabel, systemImage: "clock", footnote: String(format: "%.1f hours", stats.hoursWatched), accent: Theme.huntTeal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Favourite genres", subtitle: "Weighted by watched episodes.")
                    if stats.favouriteGenres.isEmpty {
                        GlassCard {
                            Text("Watch a few episodes to see genre trends.")
                                .foregroundStyle(Theme.parchment.opacity(0.7))
                        }
                    } else {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(Array(stats.favouriteGenres.enumerated()), id: \.element.name) { index, genre in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(genre.name)
                                                .foregroundStyle(Theme.cream)
                                            Spacer()
                                            Text("\(genre.count)")
                                                .foregroundStyle(Theme.parchment.opacity(0.7))
                                                .monospacedDigit()
                                        }
                                        .font(.subheadline.weight(.medium))
                                        GenreCountBar(
                                            progress: CGFloat(genre.count) / CGFloat(max(maxGenre, 1)),
                                            color: Theme.mapMark(at: index)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .pirateScreen()
    }
}

private struct GenreCountBar: View {
    let progress: CGFloat
    let color: Color

    var body: some View {
        Capsule()
            .fill(Theme.navy)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(color)
                    .scaleEffect(x: min(max(progress, 0), 1), y: 1, anchor: .leading)
            }
            .frame(height: 8)
            .clipped()
    }
}
