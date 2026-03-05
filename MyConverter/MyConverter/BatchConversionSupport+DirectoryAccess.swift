import AppKit
import Foundation

extension BatchConversionSupport {
    static func presentBatchDirectoryAccessPanel(
        suggestedDirectory: URL,
        outputLabel: String
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = suggestedDirectory
        panel.prompt = "Choose Folder"
        panel.title = "Choose \(outputLabel) Output Folder"
        panel.message = "Batch conversion needs folder access. Select a folder to save all converted files."

        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }

    static func prepareBatchDirectoryAccess(
        sourceURLs: [URL],
        destinationURLsBySourceID: [String: URL],
        fileExtension: String,
        outputLabel: String
    ) -> PreparedBatchDirectoryAccess? {
        guard sourceURLs.count > 1 else {
            return .init(
                destinationURLsBySourceID: destinationURLsBySourceID,
                batchDirectoryURL: nil,
                shouldStopAccessing: false
            )
        }

        let firstSourceID = ContentViewModelSupport.sourceIdentifier(for: sourceURLs[0])
        guard let firstDestinationURL = destinationURLsBySourceID[firstSourceID] else {
            return nil
        }

        let initialDirectoryURL = firstDestinationURL.deletingLastPathComponent()
        let initialAccess = initialDirectoryURL.startAccessingSecurityScopedResource()
        if initialAccess {
            return .init(
                destinationURLsBySourceID: destinationURLsBySourceID,
                batchDirectoryURL: initialDirectoryURL,
                shouldStopAccessing: true
            )
        }

        guard let grantedDirectoryURL = presentBatchDirectoryAccessPanel(
            suggestedDirectory: initialDirectoryURL,
            outputLabel: outputLabel
        ) else {
            return nil
        }

        let grantedAccess = grantedDirectoryURL.startAccessingSecurityScopedResource()
        guard grantedAccess else {
            return nil
        }

        let remappedDestinations = remappedBatchDestinationURLs(
            sourceURLs: sourceURLs,
            originalDestinationsBySourceID: destinationURLsBySourceID,
            outputDirectory: grantedDirectoryURL,
            fileExtension: fileExtension
        )

        return .init(
            destinationURLsBySourceID: remappedDestinations,
            batchDirectoryURL: grantedDirectoryURL,
            shouldStopAccessing: true
        )
    }
}
