import Foundation

enum FFmpegBinaryLocator {
    nonisolated private static let cacheQueue = DispatchQueue(label: "myconverter.ffmpeg.path.cache")
    nonisolated(unsafe) private static var cachedPath: String?? = nil
    nonisolated(unsafe) private static var lookupTime: UInt64 = 0
    nonisolated private static let nilCacheTTL: UInt64 = 30_000_000_000

    nonisolated static func findPath() -> String? {
        let now = DispatchTime.now().uptimeNanoseconds
        let cacheSnapshot = cacheQueue.sync {
            (cachedPath, lookupTime)
        }

        if let cached = cacheSnapshot.0 {
            if let path = cached, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }

            let nilCacheAge = now >= cacheSnapshot.1 ? now - cacheSnapshot.1 : 0
            if cached == nil && nilCacheAge < nilCacheTTL {
                return nil
            }
        }

        let resolved = resolvePath()
        cacheQueue.sync {
            cachedPath = resolved
            lookupTime = now
        }
        return resolved
    }

    nonisolated private static func resolvePath() -> String? {
        var candidates: [String] = []

        if let bundled = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            candidates.append(bundled)
        }
        if let resourcePath = Bundle.main.resourceURL?.path {
            candidates.append("\(resourcePath)/ffmpeg")
            candidates.append("\(resourcePath)/bin/ffmpeg")
        }
        if let executableDir = Bundle.main.executableURL?.deletingLastPathComponent().path {
            candidates.append("\(executableDir)/ffmpeg")
            candidates.append("\(executableDir)/bin/ffmpeg")
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ])

        if let fixed = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixed
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for directory in path.split(separator: ":") {
                let candidate = "\(directory)/ffmpeg"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        return nil
    }
}
