import Foundation

extension ImageConversionEngine {
    nonisolated static func ffmpegCanDecodeSource(
        runtime: any FFmpegRuntime,
        inputURL: URL
    ) -> Bool {
        (try? FFmpegStagingSupport.withStagedInputSync(
            for: inputURL,
            makeError: { code, message in
                ImageConversionError.ffmpegFailed(code, message)
            },
            operation: { stagedInputURL in
                let result = runtime.runCommandSync(
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
        )) ?? false
    }
}
