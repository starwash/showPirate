import SwiftUI

struct WatchProgressBar: View {
    let progress: Double
    var height: CGFloat = 8

    var body: some View {
        Capsule()
            .fill(Theme.huntRed)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Theme.watchedGreen)
                    .scaleEffect(x: min(max(progress, 0), 1), y: 1, anchor: .leading)
            }
            .frame(height: height)
            .clipped()
        .accessibilityLabel("Watch progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}
