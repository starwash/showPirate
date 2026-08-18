import SwiftUI
import AppKit

@main
enum AppLauncher {
    static func main() {
        #if DEBUG
        if CommandLine.arguments.contains(where: { $0.hasPrefix("--export-screenshots") }) {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)

            let semaphore = DispatchSemaphore(value: 0)
            var exportError: String?

            Task { @MainActor in
                defer { semaphore.signal() }
                do {
                    let directory = ScreenshotExporter.outputDirectoryURL()
                    if CommandLine.arguments.contains(where: { $0.hasPrefix("--export-library-light") }) {
                        try await ScreenshotExporter.exportLibraryLight(to: directory)
                    } else {
                        try await ScreenshotExporter.export(to: directory)
                    }
                    print("Exported screenshots to \(directory.path)")
                } catch {
                    exportError = error.localizedDescription
                }
            }

            while semaphore.wait(timeout: .now() + 0.05) == .timedOut {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            }

            if let exportError {
                fputs("Screenshot export failed: \(exportError)\n", stderr)
                exit(1)
            }
            exit(0)
        }
        #endif
        ShowPirateApp.main()
    }
}
