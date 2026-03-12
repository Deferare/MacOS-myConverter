import Foundation

extension ContentViewModel {
    func handleFileImportResult(_ result: Result<[URL], Error>, for kind: MediaKind) {
        switch result {
        case .success(let urls):
            #if os(iOS)
            print("[Import] kind=\(kind.rawValue) returnedURLs=\(urls.count) paths=\(urls.map(\.path))")
            #endif
            applyImportedSources(urls, for: kind)
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }

    func applyImportedSources(_ urls: [URL], for kind: MediaKind) {
        let acceptedURLs = acceptedInputURLs(urls, accept: kind.acceptsInput(_:))
        #if os(iOS)
        let effectiveURLs = uniqueStandardizedURLs(urls.filter { !$0.hasDirectoryPath })
        #else
        let effectiveURLs = acceptedURLs
        #endif
        #if os(iOS)
        print("[Import] kind=\(kind.rawValue) acceptedURLs=\(acceptedURLs.count) effectiveURLs=\(effectiveURLs.count)")
        #endif
        guard !effectiveURLs.isEmpty else { return }

        let existingSelection = selectedSourceURLs(for: kind)
        let mergedSelection = uniqueStandardizedURLs(existingSelection + effectiveURLs)
        #if os(iOS)
        print("[Import] kind=\(kind.rawValue) mergedSelection=\(mergedSelection.map(\.lastPathComponent))")
        #endif
        applySelectedSources(mergedSelection, for: kind)
    }

    func handleFileImportResult(_ result: Result<[URL], Error>, for selectedTab: ConverterTab) {
        guard let kind = selectedTab.mediaKind else { return }
        handleFileImportResult(result, for: kind)
    }
}
