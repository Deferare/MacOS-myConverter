import Foundation

extension VideoConversionEngine {
    static func sandboxOutputDirectory(bundleIdentifier: String?) throws -> URL {
        let appSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let identifier = bundleIdentifier ?? "MyConverter"
        let outputDirectory = appSupportDirectory
            .appendingPathComponent(identifier, isDirectory: true)
            .appendingPathComponent("Converted", isDirectory: true)

        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return outputDirectory
    }

    static func uniqueOutputURL(
        for sourceURL: URL,
        format: VideoFormatOption,
        in outputDirectory: URL
    ) -> URL {
        OutputPathUtilities.uniqueOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension,
            in: outputDirectory
        )
    }

    static func temporaryOutputURL(for sourceURL: URL, format: VideoFormatOption) -> URL {
        OutputPathUtilities.temporaryOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension
        )
    }

    static func uniqueOutputURL(
        for sourceURL: URL,
        format: AudioFormatOption,
        in outputDirectory: URL
    ) -> URL {
        OutputPathUtilities.uniqueOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension,
            in: outputDirectory
        )
    }

    static func temporaryOutputURL(for sourceURL: URL, format: AudioFormatOption) -> URL {
        OutputPathUtilities.temporaryOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension
        )
    }

    static func saveConvertedOutput(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        do {
            return try OutputPathUtilities.saveConvertedOutput(from: sourceURL, to: destinationURL)
        } catch let saveError as OutputPathUtilities.SaveOutputError {
            switch saveError {
            case let .outputSaveFailed(path, message):
                throw ConversionError.outputSaveFailed(path, message)
            }
        }
    }

    static func isFFmpegAvailable() -> Bool {
        FFmpegBinaryLocator.findPath() != nil
    }
}
