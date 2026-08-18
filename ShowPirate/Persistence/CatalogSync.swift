import AppKit
import CryptoKit
import Darwin
import Foundation
import Observation

@Observable
@MainActor
final class CatalogSync {
    static let shared = CatalogSync()
    static let fileName = "showPirate-library.json"

    private static let bookmarkKey = "catalog.sync.folderBookmark"
    private static let appliedExportKey = "catalog.sync.appliedExportedAt"

    private(set) var folderPath: String?
    private(set) var statusMessage: String = "Not connected"
    private(set) var isConnected = false
    private(set) var lastSyncedAt: Date?

    private weak var store: LibraryStore?
    private var folderURL: URL?
    private var fileDescriptor: Int32 = -1
    private var watcher: DispatchSourceFileSystemObject?
    private var exportTask: Task<Void, Never>?
    private var lastWrittenHash: String?
    private var isApplyingRemote = false
    private var isAccessing = false

    func attach(store: LibraryStore) {
        self.store = store
        restoreFolder()
        Task { await reconcileOnLaunch() }
    }

    var folderLabel: String {
        guard let folderPath else { return "No folder selected" }
        return (folderPath as NSString).abbreviatingWithTildeInPath
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.message = "Choose a Dropbox, iCloud Drive, or Syncthing folder. showPirate keeps showPirate-library.json there."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        connect(to: url)
        Task { await reconcileOnLaunch() }
    }

    func disconnect() {
        stopWatching()
        stopAccessing()
        folderURL = nil
        folderPath = nil
        isConnected = false
        lastWrittenHash = nil
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        statusMessage = "Not connected"
    }

    func noteLocalChange() {
        guard isConnected, !isApplyingRemote else { return }
        exportTask?.cancel()
        exportTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.exportNow()
        }
    }

    private func connect(to url: URL) {
        stopWatching()
        stopAccessing()
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            folderURL = url
            folderPath = url.path
            isConnected = true
            isAccessing = url.startAccessingSecurityScopedResource()
            statusMessage = "Connected"
        } catch {
            statusMessage = error.localizedDescription
            isConnected = false
        }
    }

    private func restoreFolder() {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale {
                connect(to: url)
            } else {
                folderURL = url
                folderPath = url.path
                isConnected = true
                isAccessing = url.startAccessingSecurityScopedResource()
                statusMessage = "Connected"
            }
        } catch {
            statusMessage = "Could not reopen the sync folder. Choose it again."
            isConnected = false
        }
    }

    private func catalogURL() -> URL? {
        folderURL?.appending(path: Self.fileName)
    }

    private func reconcileOnLaunch() async {
        guard isConnected, let store else { return }
        startWatching()
        let fileURL = catalogURL()
        let fileCatalog = fileURL.flatMap { loadCatalog(from: $0) }
        let localShows = store.allShows()

        if let fileCatalog {
            let applied = UserDefaults.standard.object(forKey: Self.appliedExportKey) as? Date ?? .distantPast
            if localShows.isEmpty || fileCatalog.exportedAt > applied {
                apply(fileCatalog, fromRemote: true)
                statusMessage = "Loaded catalog from folder"
            } else {
                exportNow()
            }
        } else if !localShows.isEmpty {
            exportNow()
        } else {
            statusMessage = "Waiting for catalog file"
        }
    }

    private func exportNow() {
        guard !isApplyingRemote, let store, let fileURL = catalogURL() else { return }
        do {
            let catalog = CatalogCodec.makeCatalog(from: store.allShows(), exportedAt: .now)
            let data = try CatalogCodec.encoder().encode(catalog)
            try data.write(to: fileURL, options: .atomic)
            lastWrittenHash = Self.hash(data)
            UserDefaults.standard.set(catalog.exportedAt, forKey: Self.appliedExportKey)
            lastSyncedAt = catalog.exportedAt
            statusMessage = "Saved to folder"
            startWatching()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func importFromDisk() {
        guard !isApplyingRemote, let fileURL = catalogURL() else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else { return }
        if Self.hash(data) == lastWrittenHash { return }
        guard let catalog = try? CatalogCodec.decoder().decode(CatalogFile.self, from: data) else { return }
        let applied = UserDefaults.standard.object(forKey: Self.appliedExportKey) as? Date ?? .distantPast
        if catalog.exportedAt <= applied {
            return
        }
        apply(catalog, fromRemote: true)
        lastWrittenHash = Self.hash(data)
        statusMessage = "Updated from folder"
    }

    private func apply(_ catalog: CatalogFile, fromRemote: Bool) {
        guard let store else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        do {
            try store.replaceCatalog(catalog)
            UserDefaults.standard.set(catalog.exportedAt, forKey: Self.appliedExportKey)
            lastSyncedAt = catalog.exportedAt
            if fromRemote, let fileURL = catalogURL(), let data = try? Data(contentsOf: fileURL) {
                lastWrittenHash = Self.hash(data)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func loadCatalog(from url: URL) -> CatalogFile? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? CatalogCodec.decoder().decode(CatalogFile.self, from: data)
    }

    private func startWatching() {
        stopWatching()
        guard let folderURL else { return }
        let descriptor = open(folderURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        fileDescriptor = descriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.handleFolderChange()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        watcher = source
        source.resume()
    }

    private func handleFolderChange() {
        guard !isApplyingRemote else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            self.importFromDisk()
        }
    }

    private func stopWatching() {
        watcher?.cancel()
        watcher = nil
        fileDescriptor = -1
    }

    private func stopAccessing() {
        if isAccessing {
            folderURL?.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
