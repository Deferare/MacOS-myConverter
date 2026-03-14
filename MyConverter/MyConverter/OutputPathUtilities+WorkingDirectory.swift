import Foundation

extension OutputPathUtilities {
    nonisolated private static let cachedWorkingDirectoryURL: URL = {
        resolveWorkingDirectoryURL()
    }()

    nonisolated static func workingDirectoryURL() -> URL {
        let cached = cachedWorkingDirectoryURL
        if ensureDirectoryExists(cached) {
            return cached
        }
        return resolveWorkingDirectoryURL()
    }

    nonisolated private static func resolveWorkingDirectoryURL() -> URL {
        let fileManager = FileManager.default

        if let appSupportDirectory = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            let identifier = Bundle.main.bundleIdentifier ?? "MyConverter"
            let workingDirectory = appSupportDirectory
                .appendingPathComponent(identifier, isDirectory: true)
                .appendingPathComponent("Working", isDirectory: true)
            if ensureDirectoryExists(workingDirectory) {
                return workingDirectory
            }
        }

        let fallbackDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("MyConverterWorking", isDirectory: true)
        _ = ensureDirectoryExists(fallbackDirectory)
        return fallbackDirectory
    }

    nonisolated static func ensureDirectoryExists(_ url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return true
        } catch {
            return false
        }
    }
}
