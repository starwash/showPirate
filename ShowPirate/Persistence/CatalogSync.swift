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
    private static let pathKey = "catalog.sync.folderPath"
    private static let securityScopeKey = "catalog.sync.bookmarkIsSecurityScoped"
    private static let appliedExportKey = "catalog.sync.appliedExportedAt"

    private(set) var folderPath: String?
    private(set) var statusMessage: String = "Not connected"
    private(set) var isConnected = false
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?

    private weak var store: LibraryStore?
    private var folderURL: URL?
    private var accessURL: URL?
    private var fileDescriptor: Int32 = -1
    private var watcher: DispatchSourceFileSystemObject?
    private var pollTask: Task<Void, Never>?
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
        isSyncing = false
        lastWrittenHash = nil
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        UserDefaults.standard.removeObject(forKey: Self.pathKey)
        UserDefaults.standard.removeObject(forKey: Self.securityScopeKey)
        statusMessage = "Not connected"
    }

    func syncNow() {
        guard isConnected, !isSyncing else { return }
        Task { await performManualSync() }
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
        beginAccess(url)

        do {
            let folder = try prepareFolder(url)
            persistAccess(to: folder)
            folderURL = folder
            folderPath = folder.path
            isConnected = true
            statusMessage = "Connected"
        } catch {
            stopAccessing()
            folderURL = nil
            folderPath = nil
            isConnected = false
            statusMessage = Self.friendlyMessage(for: error)
        }
    }

    private func restoreFolder() {
        do {
            let url = try resolvedStoredFolder()
            folderURL = url
            folderPath = url.path
            beginAccess(url)
            isConnected = true
            statusMessage = "Connected"
        } catch {
            if UserDefaults.standard.data(forKey: Self.bookmarkKey) != nil
                || UserDefaults.standard.string(forKey: Self.pathKey) != nil {
                statusMessage = "Could not reopen the sync folder. Choose it again."
            }
            isConnected = false
        }
    }

    private func resolvedStoredFolder() throws -> URL {
        if let bookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey) {
            var stale = false
            let usesScope = UserDefaults.standard.bool(forKey: Self.securityScopeKey)
            let options: URL.BookmarkResolutionOptions = usesScope ? [.withSecurityScope, .withoutUI] : [.withoutUI]
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                if stale {
                    persistAccess(to: url)
                }
                return url
            }
            if usesScope, let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return url
            }
        }
        if let path = UserDefaults.standard.string(forKey: Self.pathKey) {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        throw SyncError.folderUnavailable
    }

    private func persistAccess(to url: URL) {
        UserDefaults.standard.set(url.path, forKey: Self.pathKey)
        if let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
            UserDefaults.standard.set(true, forKey: Self.securityScopeKey)
            return
        }
        if let data = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
            UserDefaults.standard.set(false, forKey: Self.securityScopeKey)
            return
        }
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        UserDefaults.standard.set(false, forKey: Self.securityScopeKey)
    }

    private func prepareFolder(_ url: URL) throws -> URL {
        let folder = url.resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir) {
            guard isDir.boolValue else { throw SyncError.notAFolder }
        } else {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        if Self.isUbiquitous(folder) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: folder)
        }
        _ = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.nameKey])
        return folder
    }

    private func catalogURL() -> URL? {
        folderURL?.appending(path: Self.fileName)
    }

    private func downloadCloudCopyIfNeeded() async {
        guard let folderURL else { return }
        if Self.isUbiquitous(folderURL) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: folderURL)
        }
        if let fileURL = catalogURL(), Self.isUbiquitous(fileURL) || Self.isUbiquitous(folderURL) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
            for _ in 0..<15 {
                let status = try? fileURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
                if status == .current || status == .downloaded { break }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    private func performManualSync() async {
        guard isConnected else { return }
        isSyncing = true
        statusMessage = "Syncing…"
        await downloadCloudCopyIfNeeded()
        await reconcile()
        if statusMessage == "Syncing…" {
            statusMessage = "Already up to date"
        }
        isSyncing = false
    }

    private func reconcileOnLaunch() async {
        await reconcile()
    }

    private func reconcile() async {
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
        } else {
            exportNow()
        }
    }

    private func exportNow() {
        guard !isApplyingRemote, let store, let fileURL = catalogURL() else { return }
        do {
            let catalog = CatalogCodec.makeCatalog(from: store.allShows(), exportedAt: .now)
            let data = try CatalogCodec.encoder().encode(catalog)
            try writeData(data, to: fileURL)
            lastWrittenHash = Self.hash(data)
            UserDefaults.standard.set(catalog.exportedAt, forKey: Self.appliedExportKey)
            lastSyncedAt = catalog.exportedAt
            statusMessage = "Saved to folder"
            startWatching()
        } catch {
            statusMessage = Self.friendlyMessage(for: error)
        }
    }

    private func importFromDisk() {
        guard !isApplyingRemote, let fileURL = catalogURL() else { return }
        guard let data = try? readData(from: fileURL) else { return }
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
            if fromRemote, let fileURL = catalogURL(), let data = try? readData(from: fileURL) {
                lastWrittenHash = Self.hash(data)
            }
        } catch {
            statusMessage = Self.friendlyMessage(for: error)
        }
    }

    private func loadCatalog(from url: URL) -> CatalogFile? {
        guard let data = try? readData(from: url) else { return nil }
        return try? CatalogCodec.decoder().decode(CatalogFile.self, from: data)
    }

    private func writeData(_ data: Data, to url: URL) throws {
        var coordinatorError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { coordinated in
            do {
                try data.write(to: coordinated, options: [])
            } catch {
                writeError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let writeError { throw writeError }
    }

    private func readData(from url: URL) throws -> Data {
        var coordinatorError: NSError?
        var fileData: Data?
        var readError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinatorError) { coordinated in
            do {
                fileData = try Data(contentsOf: coordinated)
            } catch {
                readError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let readError { throw readError }
        guard let fileData else { throw SyncError.folderUnavailable }
        return fileData
    }

    private func startWatching() {
        stopWatching()
        guard let folderURL else { return }

        let descriptor = open(folderURL.path, O_EVTONLY)
        if descriptor >= 0 {
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

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                self?.importFromDisk()
            }
        }
    }

    private func handleFolderChange() {
        guard !isApplyingRemote else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            self.importFromDisk()
        }
    }

    private func stopWatching() {
        pollTask?.cancel()
        pollTask = nil
        watcher?.cancel()
        watcher = nil
        fileDescriptor = -1
    }

    private func beginAccess(_ url: URL) {
        stopAccessing()
        accessURL = url
        isAccessing = url.startAccessingSecurityScopedResource()
    }

    private func stopAccessing() {
        if isAccessing {
            accessURL?.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
        accessURL = nil
    }

    private static func isUbiquitous(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true
            || url.path.contains("/Library/Mobile Documents/")
    }

    private static func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, [4, 256, 257, 260].contains(nsError.code) {
            return "Could not open this folder. If it is in iCloud Drive, open the folder once in Finder so it downloads, then choose it again."
        }
        return error.localizedDescription
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private enum SyncError: LocalizedError {
    case notAFolder
    case folderUnavailable

    var errorDescription: String? {
        switch self {
        case .notAFolder:
            return "That item is not a folder."
        case .folderUnavailable:
            return "The sync folder is no longer available."
        }
    }
}
