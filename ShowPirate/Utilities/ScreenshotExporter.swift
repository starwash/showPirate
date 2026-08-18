#if DEBUG
import AppKit
import SwiftData
import SwiftUI

enum ScreenshotExporter {
    private static let size = CGSize(width: 1240, height: 800)

    static func outputDirectoryURL() -> URL {
        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--export-screenshots=") }) {
            let path = String(argument.dropFirst("--export-screenshots=".count))
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("docs/screenshots", isDirectory: true)
    }

    @MainActor
    static func export(to directory: URL) async throws {
        let schema = Schema([Show.self, Season.self, Episode.self, Genre.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        SampleData.seed(in: context, force: true)
        try context.save()

        let store = LibraryStore(context: context)
        await store.warmWatchCaches()
        await prefetchPosterImages(from: context)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for item in SidebarItem.allCases {
            let view = AppScreenshotShell(selection: item) {
                detailView(for: item, store: store)
            }
            .environment(store)
            .modelContainer(container)
            .pirateAppearance(.dark)

            try await render(view, named: item.rawValue, in: directory, appearance: .dark)
        }
    }

    @MainActor
    static func exportLibraryLight(to directory: URL) async throws {
        let schema = Schema([Show.self, Season.self, Episode.self, Genre.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        SampleData.seed(in: context, force: true)
        try context.save()

        let store = LibraryStore(context: context)
        await store.warmWatchCaches()
        await prefetchPosterImages(from: context)
        await warmupDecodedPosters(from: context)

        UserDefaults.standard.set(LibraryLayout.grid.rawValue, forKey: "library.layout")
        UserDefaults.standard.set(LibrarySort.name.rawValue, forKey: "library.sort")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let view = AppScreenshotShell(selection: .library) {
            LibraryView().environment(\.sidebarTabIsActive, true)
        }
        .environment(store)
        .modelContainer(container)
        .pirateAppearance(.light)

        try await render(view, named: "library-light", in: directory, appearance: .light)
    }

    @MainActor
    @ViewBuilder
    private static func detailView(for item: SidebarItem, store: LibraryStore) -> some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .library:
            LibraryView().environment(\.sidebarTabIsActive, true)
        case .search:
            SearchScreenshotView()
        case .calendar:
            CalendarView().environment(\.sidebarTabIsActive, true)
        case .statistics:
            StatisticsView()
        case .settings:
            SettingsScreenshotView()
        }
    }

    @MainActor
    private static func prefetchPosterImages(from context: ModelContext) async {
        let shows = (try? context.fetch(FetchDescriptor<Show>())) ?? []
        var urls: [URL] = []
        for show in shows {
            if let url = ImageURLBuilder.url(path: show.posterPath, size: .poster) {
                urls.append(url)
            }
        }
        for sample in ScreenshotSamples.all {
            if let url = ImageURLBuilder.url(path: sample.posterPath, size: .poster) {
                urls.append(url)
            }
        }
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = await ImageCache.shared.data(from: url)
                }
            }
        }
        try? await Task.sleep(for: .milliseconds(300))
    }

    @MainActor
    private static func warmupDecodedPosters(from context: ModelContext) async {
        let shows = (try? context.fetch(FetchDescriptor<Show>())) ?? []
        var urls: [URL] = []
        for show in shows {
            if let url = ImageURLBuilder.url(path: show.posterPath, size: .poster) {
                urls.append(url)
            }
        }
        for sample in ScreenshotSamples.all {
            if let url = ImageURLBuilder.url(path: sample.posterPath, size: .poster) {
                urls.append(url)
            }
        }
        await ScreenshotImageWarmup.preload(urls: urls, maxPixelSize: 300)
        print("Warmed \(urls.count) poster URLs")
    }

    @MainActor
    private static func render<V: View>(
        _ view: V,
        named: String,
        in directory: URL,
        appearance: AppearancePreference,
        settleSeconds: TimeInterval = 3.0
    ) async throws {
        NSApp.appearance = appearance == .light
            ? NSAppearance(named: .aqua)
            : NSAppearance(named: .darkAqua)

        let content = view
            .frame(width: size.width, height: size.height)
            .preferredColorScheme(appearance.resolvedColorScheme)
            .pirateAppearance(appearance)

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: NSSize(width: size.width, height: size.height))

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.setFrameOrigin(.zero)
        window.makeKeyAndOrderFront(nil)
        hostingView.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .seconds(settleSeconds))

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw ExportError.renderFailed(named)
        }
        rep.size = hostingView.bounds.size
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [.compressionFactor: 0.82]) else {
            throw ExportError.encodeFailed(named)
        }
        try png.write(to: directory.appendingPathComponent("\(named).png"))
        window.orderOut(nil)
    }

    private enum ExportError: LocalizedError {
        case renderFailed(String)
        case encodeFailed(String)

        var errorDescription: String? {
            switch self {
            case .renderFailed(let name): "Could not render \(name)."
            case .encodeFailed(let name): "Could not encode \(name)."
            }
        }
    }
}

private struct AppScreenshotShell<Detail: View>: View {
    let selection: SidebarItem
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        NavigationSplitView {
            List(selection: .constant(selection)) {
                Section("Navigate") {
                    ForEach(SidebarItem.allCases.filter { $0 != .settings }) { item in
                        Label(item.title, systemImage: item.systemImage)
                            .tag(item)
                    }
                }
                Section {
                    Label(SidebarItem.settings.title, systemImage: SidebarItem.settings.systemImage)
                        .tag(SidebarItem.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
            .navigationTitle("showPirate")
        } detail: {
            NavigationStack {
                detail()
                    .navigationTitle(selection.title)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Theme.gold)
    }
}

private struct SearchScreenshotView: View {
    private let trending = ScreenshotSamples.shows(prefix: 6)
    private let popular = ScreenshotSamples.shows(from: 3, count: 5)
    private let onAir = ScreenshotSamples.shows(from: 1, count: 5)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.gold)
                TextField("Search TV shows on TMDB", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
            }
            .padding(14)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    screenshotRow(title: "Trending this week", shows: trending)
                    screenshotRow(title: "Popular", shows: popular)
                    screenshotRow(title: "On the air", shows: onAir)
                }
                .padding(24)
            }
        }
        .pirateScreen()
    }

    private func screenshotRow(title: String, shows: [TMDBSearchShow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(shows) { show in
                        VStack(alignment: .leading, spacing: 8) {
                            PosterView(path: show.posterPath, width: 160)
                            Text(show.name)
                                .font(.headline)
                                .foregroundStyle(Theme.cream)
                                .lineLimit(1)
                            Text(show.yearLabel.isEmpty ? "TV Series" : show.yearLabel)
                                .font(.caption)
                                .foregroundStyle(Theme.parchment.opacity(0.7))
                            Label("Add", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Theme.huntRed.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(width: 160, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct SettingsScreenshotView: View {
    var body: some View {
        SettingsView()
            .onAppear {
                UserDefaults.standard.set("screenshot-placeholder-key", forKey: APIConfig.settingsKey)
            }
    }
}

private enum ScreenshotSamples {
    private static let json = """
    [
      {"id":1396,"name":"Breaking Bad","poster_path":"/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg","first_air_date":"2008-01-20"},
      {"id":95396,"name":"Severance","poster_path":"/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg","first_air_date":"2022-02-18"},
      {"id":136315,"name":"The Bear","poster_path":"/6FVNnVk0SZFdzb9dkvOr13XyyM4.jpg","first_air_date":"2022-06-23"},
      {"id":100088,"name":"The Last of Us","poster_path":"/dmo6TYuuJgaYinXBPjrgG9mB5od.jpg","first_air_date":"2023-01-15"},
      {"id":66732,"name":"Stranger Things","poster_path":"/uOOtwVbSr4QDjAGIifLDwpb2Pdl.jpg","first_air_date":"2016-07-15"},
      {"id":2316,"name":"The Office","poster_path":"/7DJKHzAi83BmQrWLrYYOqcoKfhR.jpg","first_air_date":"2005-03-24"},
      {"id":76331,"name":"Succession","poster_path":"/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg","first_air_date":"2018-06-03"},
      {"id":97546,"name":"Ted Lasso","poster_path":"/uRHsiw1wLxPHFXkkv4Ix1s0O6f4.jpg","first_air_date":"2020-08-14"}
    ]
    """

    static func shows(prefix count: Int) -> [TMDBSearchShow] {
        Array(decoded.prefix(count))
    }

    static func shows(from start: Int, count: Int) -> [TMDBSearchShow] {
        Array(decoded.dropFirst(start).prefix(count))
    }

    static var all: [TMDBSearchShow] {
        decoded
    }

    private static let decoded: [TMDBSearchShow] = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let data = json.data(using: .utf8),
              let shows = try? decoder.decode([TMDBSearchShow].self, from: data) else {
            return []
        }
        return shows
    }()
}
#endif