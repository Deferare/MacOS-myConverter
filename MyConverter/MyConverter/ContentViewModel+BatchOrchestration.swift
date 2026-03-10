import Foundation

extension ContentViewModel {
    func prepareBatchContext(
        primarySourceURL: URL,
        queuedSourceURLs: [URL],
        fileExtension: String,
        outputLabel: String,
        preferredOutputDirectory: URL? = nil
    ) -> PreparedBatchConversionContext? {
        BatchConversionSupport.prepareContext(
            sourceURLs: [primarySourceURL] + queuedSourceURLs,
            fileExtension: fileExtension,
            outputLabel: outputLabel,
            preferredOutputDirectory: preferredOutputDirectory
        )
    }

    func selectedOutputDirectoryURL(for kind: MediaKind) -> URL? {
        switch kind {
        case .video:
            return selectedVideoOutputDirectoryURL
        case .image:
            return selectedImageOutputDirectoryURL
        case .audio:
            return selectedAudioOutputDirectoryURL
        }
    }

    func setSelectedOutputDirectoryURL(_ url: URL?, for kind: MediaKind) {
        switch kind {
        case .video:
            selectedVideoOutputDirectoryURL = url
        case .image:
            selectedImageOutputDirectoryURL = url
        case .audio:
            selectedAudioOutputDirectoryURL = url
        }
    }

    func hasSelectedOutputDirectory(for kind: MediaKind) -> Bool {
        selectedOutputDirectoryURL(for: kind) != nil
    }

    @discardableResult
    func chooseOutputDirectory(for kind: MediaKind) -> Bool {
        let suggestedDirectory = selectedOutputDirectoryURL(for: kind)
            ?? selectedSourceURLs(for: kind).first?.deletingLastPathComponent()
            ?? FileManager.default.homeDirectoryForCurrentUser

        guard let selectedDirectory = BatchConversionSupport.presentBatchDirectoryAccessPanel(
            suggestedDirectory: suggestedDirectory,
            outputLabel: kind.conversionMetadata.outputLabel,
            fileCount: max(selectedFileCount(for: kind), 1)
        ) else {
            return false
        }

        setSelectedOutputDirectoryURL(selectedDirectory.standardizedFileURL, for: kind)
        return true
    }

    func abbreviatedOutputDirectoryPath(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}
