import Foundation

enum CatalogAutoRefresh {
    static let lastRefreshKey = "library.lastAutomaticRefresh"
    static let interval: TimeInterval = 24 * 60 * 60

    static var lastRefresh: Date? {
        UserDefaults.standard.object(forKey: lastRefreshKey) as? Date
    }

    static func markRefreshed(at date: Date = .now) {
        UserDefaults.standard.set(date, forKey: lastRefreshKey)
    }

    @MainActor
    static func runIfNeeded(using store: LibraryStore) async {
        guard APIConfig.hasAPIKey else { return }
        if let last = lastRefresh, Date().timeIntervalSince(last) < interval {
            return
        }
        let result = await store.refreshLibrary()
        if result.refreshed == 0 && result.failed > 0 {
            return
        }
        markRefreshed()
    }
}
