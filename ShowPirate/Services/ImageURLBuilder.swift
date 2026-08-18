import Foundation

enum ImageSize: String {
    case posterSmall = "w185"
    case poster = "w342"
    case posterLarge = "w500"
    case backdrop = "w780"
    case backdropLarge = "w1280"
    case still = "w300"
    case logo = "w92"
    case original = "original"
}

enum ImageURLBuilder {
    static func url(path: String?, size: ImageSize) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        return APIConfig.imageBaseURL
            .appending(path: size.rawValue)
            .appending(path: String(normalized.dropFirst()))
    }
}
