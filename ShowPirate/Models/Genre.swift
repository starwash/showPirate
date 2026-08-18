import Foundation
import SwiftData

@Model
final class Genre {
    var tmdbID: Int = 0
    var name: String = ""

    var shows: [Show] = []

    init(tmdbID: Int, name: String, shows: [Show] = []) {
        self.tmdbID = tmdbID
        self.name = name
        self.shows = shows
    }
}
