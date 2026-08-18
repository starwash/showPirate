import AppKit
import ImageIO
import SwiftUI

struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL?
    var maxPixelSize: Int?
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            placeholder()
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
            if image == nil && isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: taskKey) {
            await load()
        }
        .onAppear {
            Task { await load() }
        }
    }

    private var taskKey: String {
        let size = maxPixelSize.map(String.init) ?? "full"
        return "\(url?.absoluteString ?? "nil")-\(size)"
    }

    @MainActor
    private func load() async {
        guard let url else {
            image = nil
            isLoading = false
            return
        }
        let pixelSize = maxPixelSize
        if let cached = DecodedImageCache.shared.image(for: url, maxPixelSize: pixelSize) {
            image = cached
            return
        }
        isLoading = true
        if let data = await ImageCache.shared.data(from: url) {
            let decoded = await Task.detached(priority: .userInitiated) {
                decodeImage(data, maxPixelSize: pixelSize)
            }.value
            if let decoded {
                DecodedImageCache.shared.store(decoded, for: url, maxPixelSize: pixelSize)
                image = decoded
            }
        }
        isLoading = false
    }
}

@MainActor
private final class DecodedImageCache {
    static let shared = DecodedImageCache()
    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 256
        cache.totalCostLimit = 64 * 1_024 * 1_024
    }

    private func key(for url: URL, maxPixelSize: Int?) -> NSString {
        let size = maxPixelSize.map(String.init) ?? "full"
        return "\(url.absoluteString)-\(size)" as NSString
    }

    func image(for url: URL, maxPixelSize: Int?) -> NSImage? {
        cache.object(forKey: key(for: url, maxPixelSize: maxPixelSize))
    }

    func store(_ image: NSImage, for url: URL, maxPixelSize: Int?) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key(for: url, maxPixelSize: maxPixelSize), cost: max(cost, 1))
    }
}

private nonisolated func decodeImage(_ data: Data, maxPixelSize: Int?) -> NSImage? {
    let options: [CFString: Any] = [
        kCGImageSourceShouldCache: true
    ]
    guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
        return nil
    }

    let cgImage: CGImage?
    if let maxPixelSize {
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
    } else {
        cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
    }

    guard let cgImage else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
}

#if DEBUG
enum ScreenshotImageWarmup {
    @MainActor
    static func preload(urls: [URL], maxPixelSize: Int) async {
        for url in urls {
            if DecodedImageCache.shared.image(for: url, maxPixelSize: maxPixelSize) != nil {
                continue
            }
            guard let data = await ImageCache.shared.data(from: url),
                  let image = decodeImage(data, maxPixelSize: maxPixelSize) else {
                continue
            }
            DecodedImageCache.shared.store(image, for: url, maxPixelSize: maxPixelSize)
        }
    }
}
#endif
