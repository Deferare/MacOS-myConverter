import Foundation

extension VideoConversionEngine {
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
        DefaultFFmpegRuntimeProvider().makeRuntime() != nil
    }
}
