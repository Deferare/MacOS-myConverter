import Foundation

extension ContentViewModel {
    struct ResolvedBatchOutputDirectory: Sendable {
        let outputDirectoryURL: URL
        let outputDirectoryAccessURL: URL
    }
}

extension ContentViewModel.MediaKind {
    func resolveBatchOutputDirectory(
        in viewModel: ContentViewModel,
        primarySourceURL: URL,
        preferredOutputDestination: OutputDestinationHandle?,
        preferredOutputDirectory: URL?,
        outputLabel: String,
        fileCount: Int
    ) async -> ContentViewModel.ResolvedBatchOutputDirectory? {
        if let preferredOutputDirectory {
            return ContentViewModel.ResolvedBatchOutputDirectory(
                outputDirectoryURL: preferredOutputDirectory.standardizedFileURL,
                outputDirectoryAccessURL: preferredOutputDestination?.url ?? preferredOutputDirectory
            )
        }

        guard let selectedDestination = await viewModel.services.outputDestinationCoordinator.chooseOutputDestination(
            suggestedDirectory: primarySourceURL.deletingLastPathComponent(),
            outputLabel: outputLabel,
            fileCount: fileCount
        ) else {
            return nil
        }

        return ContentViewModel.ResolvedBatchOutputDirectory(
            outputDirectoryURL: selectedDestination.url,
            outputDirectoryAccessURL: selectedDestination.url
        )
    }

    func prepareBatchConversionContext(
        sourceURLs: [URL],
        fileExtension: String,
        outputDirectory: ContentViewModel.ResolvedBatchOutputDirectory
    ) async -> PreparedBatchConversionContext? {
        await detachedTaskValue(priority: .userInitiated) {
            BatchConversionSupport.prepareContext(
                sourceURLs: sourceURLs,
                fileExtension: fileExtension,
                outputDirectoryURL: outputDirectory.outputDirectoryURL,
                outputDirectoryAccessURL: outputDirectory.outputDirectoryAccessURL
            )
        }
    }
}
