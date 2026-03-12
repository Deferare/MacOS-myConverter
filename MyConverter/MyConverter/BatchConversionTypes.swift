import Foundation

enum WorkingOutputStrategy: Sendable, Equatable {
    case destinationAdjacent
    case workingDirectoryFallback

    nonisolated static func == (lhs: WorkingOutputStrategy, rhs: WorkingOutputStrategy) -> Bool {
        switch (lhs, rhs) {
        case (.destinationAdjacent, .destinationAdjacent), (.workingDirectoryFallback, .workingDirectoryFallback):
            return true
        case (.destinationAdjacent, .workingDirectoryFallback), (.workingDirectoryFallback, .destinationAdjacent):
            return false
        }
    }
}

struct PreparedSourceConversion: Sendable {
    let sourceURL: URL
    let sourceID: String
    let destinationURL: URL
    let destinationDirectoryAccessURL: URL
    let workingOutputURL: URL
    let workingOutputStrategy: WorkingOutputStrategy
}

struct PreparedBatchConversionContext: Sendable {
    let preparedSources: [PreparedSourceConversion]
    let outputDirectoryURL: URL
    let stopAccessingBatchDirectory: @Sendable () -> Void
}
