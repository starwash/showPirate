import SwiftUI
import SwiftData

struct ShowPirateApp: App {
    private let container: ModelContainer
    @AppStorage("appearance") private var appearance: AppearancePreference = .system

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1_024 * 1_024,
            diskCapacity: 256 * 1_024 * 1_024,
            diskPath: "showPirate.urlcache"
        )
        container = PersistenceController.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 1100, minHeight: 700)
                .pirateAppearance(appearance)
                .tint(Theme.gold)
        }
        .defaultSize(width: 1240, height: 800)
        .modelContainer(container)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
