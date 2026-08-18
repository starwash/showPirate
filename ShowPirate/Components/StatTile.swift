import SwiftUI

struct StatTile: View {
    let title: String
    let value: String
    var systemImage: String
    var footnote: String? = nil
    var accent: Color = Theme.gold

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.parchment.opacity(0.7))
                    .labelStyle(.titleAndIcon)
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                if let footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(Theme.parchment.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var message: String? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .foregroundStyle(Theme.gold)
        } description: {
            if let message {
                Text(message)
                    .foregroundStyle(Theme.parchment.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
