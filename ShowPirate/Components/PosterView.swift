import SwiftUI

struct PosterView: View {
    let path: String?
    var size: ImageSize = .poster
    var cornerRadius: CGFloat = 10
    var width: CGFloat = 140

    var body: some View {
        let height = width / Theme.posterAspect
        let pixelSize = Int((width * 2).rounded())
        CachedRemoteImage(
            url: ImageURLBuilder.url(path: path, size: size),
            maxPixelSize: pixelSize
        ) {
            placeholder
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.navy)
            Image(systemName: "tv")
                .font(.title2)
                .foregroundStyle(Theme.cream)
        }
    }
}

struct BannerView: View {
    let path: String?
    /// When set, the banner is cropped to this height. When `nil`, the full 16:9 backdrop is shown.
    var height: CGFloat? = nil
    var size: ImageSize = .backdropLarge

    var body: some View {
        let pixelSize = height.map { Int(($0 * 2.5).rounded()) }
        CachedRemoteImage(
            url: ImageURLBuilder.url(path: path, size: size),
            maxPixelSize: pixelSize
        ) {
            bannerPlaceholder
        }
        .frame(maxWidth: .infinity)
        .modifier(BannerSizeModifier(height: height))
        .clipped()
    }

    private var bannerPlaceholder: some View {
        Rectangle()
            .fill(Theme.navyDeep)
    }
}

private struct BannerSizeModifier: ViewModifier {
    var height: CGFloat?

    func body(content: Content) -> some View {
        if let height {
            content.frame(height: height)
        } else {
            content.aspectRatio(Theme.bannerAspect, contentMode: .fit)
        }
    }
}
