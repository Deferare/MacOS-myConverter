import Foundation
#if os(macOS)
import AppKit
#endif

#if os(macOS)
extension BatchConversionSupport {
    static func presentBatchDirectoryAccessPanel(
        suggestedDirectory: URL,
        outputLabel: String,
        fileCount: Int
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = suggestedDirectory
        panel.prompt = "Choose Folder"
        panel.title = "Choose Output Folder"
        panel.message = fileCount > 1
            ? "Select the folder where converted \(outputLabel.lowercased()) files will be saved. Converted outputs are saved only to this folder using the original file names."
            : "Select the folder where the converted \(outputLabel.lowercased()) file will be saved. The converted file is saved to this folder using the original file name."

        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }
}
#endif

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
