import Foundation

extension ContentViewModel.MediaKind {
    func handleFileImportResult(
        _ result: Result<[URL], Error>,
        in viewModel: ContentViewModel
    ) {
        switch result {
        case .success(let urls):
            applyImportedSources(urls, in: viewModel)
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }

    func applyImportedSources(_ urls: [URL], in viewModel: ContentViewModel) {
        let acceptedURLs = ContentViewModelSupport.uniqueStandardizedURLs(urls)
            .filter(acceptsInput(_:))
        #if os(iOS)
        let effectiveURLs = ContentViewModelSupport.uniqueStandardizedURLs(
            urls.filter { !$0.hasDirectoryPath }
        )
        #else
        let effectiveURLs = acceptedURLs
        #endif
        guard !effectiveURLs.isEmpty else { return }

        let existingSelection = mediaStateSnapshot(in: viewModel).selectedSourceURLs
        let mergedSelection = ContentViewModelSupport.uniqueStandardizedURLs(
            existingSelection + effectiveURLs
        )
        applySelectedSources(mergedSelection, in: viewModel)
    }
}
