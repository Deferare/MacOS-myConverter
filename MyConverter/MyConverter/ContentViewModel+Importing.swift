import Foundation

extension ContentViewModel {
    func handleFileImportResult(_ result: Result<[URL], Error>, for kind: MediaKind) {
        switch result {
        case .success(let urls):
            let selected = uniqueStandardizedURLs(urls)
            guard !selected.isEmpty else { return }
            applyImportedSources(selected, for: kind)
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }

    func applyImportedSources(
        _ urls: [URL],
        accept: (URL) -> Bool,
        applySelection: ([URL]) -> Void
    ) {
        let filtered = urls.filter(accept)
        guard !filtered.isEmpty else { return }
        applySelection(filtered)
    }

    func applyImportedSources(_ urls: [URL], for kind: MediaKind) {
        applyImportedSources(
            urls,
            accept: kind.acceptsInput(_:),
            applySelection: { [weak self] acceptedURLs in
                self?.applySelectedSources(acceptedURLs, for: kind)
            }
        )
    }

    func handleFileImportResult(_ result: Result<[URL], Error>, for selectedTab: ConverterTab) {
        guard let kind = selectedTab.mediaKind else { return }
        handleFileImportResult(result, for: kind)
    }
}
