import CryptoKit
import Foundation

actor ImageCache {
    static let shared = ImageCache()

    private var inflight: [URL: Task<Data?, Never>] = [:]
    private let session: URLSession
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1_024 * 1_024,
            diskCapacity: 256 * 1_024 * 1_024,
            diskPath: "showPirate.images"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        cacheDirectory = (appSupport ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appending(path: "showPirate")
            .appending(path: "posters")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func data(from url: URL) async -> Data? {
        let request = URLRequest(url: url)
        if let diskData = dataFromDisk(for: url) {
            return diskData
        }
        if let cached = session.configuration.urlCache?.cachedResponse(for: request) {
            return cached.data
        }
        if let existing = inflight[url] {
            return await existing.value
        }

        let session = self.session
        let task = Task<Data?, Never> {
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return nil
                }
                await self.storeToDisk(data, for: url)
                return data
            } catch {
                return nil
            }
        }
        inflight[url] = task
        let result = await task.value
        inflight[url] = nil
        return result
    }

    private func dataFromDisk(for url: URL) -> Data? {
        let fileURL = cachedFileURL(for: url)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    private func storeToDisk(_ data: Data, for url: URL) {
        let fileURL = cachedFileURL(for: url)
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func cachedFileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hash = digest.compactMap { String(format: "%02x", $0) }.joined()
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        return cacheDirectory.appending(path: "\(hash).\(ext)")
    }
}
