import Foundation

enum OutputPathUtilities {
    struct PreparedWorkingOutput: Sendable {
        let url: URL
        let strategy: WorkingOutputStrategy
    }

    enum SaveOutputError: Error {
        case outputSaveFailed(path: String, message: String)
    }

    enum StagedInputError: Error {
        case stagingDirectoryCreationFailed(path: String, message: String)
        case stagingCopyFailed(sourcePath: String, destinationPath: String, message: String)
    }
}

extension OutputPathUtilities.SaveOutputError: LocalizedError {
    var errorDescription: String? {
        if case let .outputSaveFailed(path, message) = self {
            return "Failed to save output to \(path): \(message)"
        }
        return nil
    }
}
