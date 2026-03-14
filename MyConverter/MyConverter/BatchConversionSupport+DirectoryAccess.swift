import Foundation

extension BatchConversionSupport {
    nonisolated static func prepareBatchDirectoryAccess(
        sourceURLs: [URL],
        destinationURLsBySourceID: [String: URL],
        outputDirectoryAccessURL: URL? = nil
    ) -> PreparedBatchDirectoryAccess? {
        let firstSourceID = ContentViewModelSupport.sourceIdentifier(for: sourceURLs[0])
        guard let firstDestinationURL = destinationURLsBySourceID[firstSourceID] else {
            return nil
        }

        let initialDirectoryURL = firstDestinationURL.deletingLastPathComponent()
        let accessURL = outputDirectoryAccessURL ?? initialDirectoryURL
        let initialAccess = accessURL.startAccessingSecurityScopedResource()
        return .init(
            destinationURLsBySourceID: destinationURLsBySourceID,
            batchDirectoryURL: accessURL,
            shouldStopAccessing: initialAccess
        )
    }
}
