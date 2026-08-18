import Foundation

enum APIConfig {
    static let tmdbBaseURL = URL(string: "https://api.themoviedb.org/3")!
    static let imageBaseURL = URL(string: "https://image.tmdb.org/t/p")!
    static let settingsKey = "tmdb.apiKey"
    private static let legacySettingsKey = "tmdb.apiKey.override"
    private static let migratedKey = "tmdb.apiKey.didMigrateLegacyOverride"

    static var apiKey: String {
        migrateLegacyKeyIfNeeded()
        return UserDefaults.standard.string(forKey: settingsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var hasAPIKey: Bool {
        !apiKey.isEmpty
    }

    static func setAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: settingsKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: settingsKey)
        }
        UserDefaults.standard.removeObject(forKey: legacySettingsKey)
    }

    private static func migrateLegacyKeyIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: migratedKey) == false else { return }
        defer { defaults.set(true, forKey: migratedKey) }

        let current = defaults.string(forKey: settingsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard current.isEmpty else { return }

        let legacy = defaults.string(forKey: legacySettingsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !legacy.isEmpty else { return }

        defaults.set(legacy, forKey: settingsKey)
        defaults.removeObject(forKey: legacySettingsKey)
    }
}
