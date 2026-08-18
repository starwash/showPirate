import SwiftUI

struct EpisodeRow: View {
    let episode: Episode
    var onToggle: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: episode.isWatched ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(episode.isWatched ? Theme.watchedGreen : Theme.huntRed)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help(episode.isWatched ? "Mark as unwatched" : "Mark as watched")
            .disabled(!episode.hasAired && !episode.isWatched)
            .controlSize(.large)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(episode.code)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(Theme.huntTeal)
                    Text(episode.name)
                        .font(.body)
                        .foregroundStyle(Theme.cream)
                        .strikethrough(episode.isWatched, color: .secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(Formatters.episodeAirLabel(episode.airDate))
                        .font(.caption)
                        .foregroundStyle(episode.isAiringToday ? Theme.huntRed : .secondary)
                }
                if !episode.overview.isEmpty {
                    Text(episode.overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 6)
        .opacity(episode.hasAired ? 1 : 0.7)
        .contextMenu {
            if episode.hasAired || episode.isWatched {
                Button(episode.isWatched ? "Mark Unwatched" : "Mark Watched", action: onToggle)
            }
        }
    }
}
