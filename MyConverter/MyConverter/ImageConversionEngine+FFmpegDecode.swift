import Foundation

extension ImageConversionEngine {
    nonisolated static func ffmpegCanDecodeSource(
        ffmpegPath: String,
        inputURL: URL
    ) -> Bool {
        let stagedInputURL: URL
        do {
            stagedInputURL = try stageInputForFFmpeg(inputURL)
        } catch {
            return false
        }
        defer {
            try? OutputPathUtilities.removeFileIfExists(at: stagedInputURL)
        }

        let result = ProcessCommandRunner.runCommandSync(
            path: ffmpegPath,
            arguments: [
                "-hide_banner",
                "-loglevel", "error",
                "-i", stagedInputURL.path,
                "-map", "0:v:0",
                "-frames:v", "1",
                "-f", "null",
                "-"
            ]
        )
        return result.terminationStatus == 0
    }

    nonisolated private static func stageInputForFFmpeg(_ inputURL: URL) throws -> URL {
        try FFmpegStagingSupport.stageInputURL(for: inputURL) { code, message in
            ImageConversionError.ffmpegFailed(code, message)
        }
    }
}
