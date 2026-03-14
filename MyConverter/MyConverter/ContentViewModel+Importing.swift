import Foundation

extension ContentViewModel {
    func handleFileImportResult(_ result: Result<[URL], Error>, for kind: MediaKind) {
        switch result {
        case .success(let urls):
            applyImportedSources(urls, for: kind)
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }

    func applyImportedSources(_ urls: [URL], for kind: MediaKind) {
        let acceptedURLs = ContentViewModelSupport.uniqueStandardizedURLs(urls)
            .filter(kind.acceptsInput(_:))
        #if os(iOS)
        let effectiveURLs = ContentViewModelSupport.uniqueStandardizedURLs(
            urls.filter { !$0.hasDirectoryPath }
        )
        #else
        let effectiveURLs = acceptedURLs
        #endif
        guard !effectiveURLs.isEmpty else { return }

        let existingSelection = kind.mediaStateSnapshot(in: self).selectedSourceURLs
        let mergedSelection = ContentViewModelSupport.uniqueStandardizedURLs(
            existingSelection + effectiveURLs
        )
        applySelectedSources(mergedSelection, for: kind)
    }

    func handleFileImportResult(_ result: Result<[URL], Error>, for selectedTab: ConverterTab) {
        guard let kind = selectedTab.mediaKind else { return }
        handleFileImportResult(result, for: kind)
    }
}
