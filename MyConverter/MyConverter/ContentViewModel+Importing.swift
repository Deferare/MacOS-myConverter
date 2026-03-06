import Foundation

extension ContentViewModel {
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
            accept: { [weak self] url in
                guard let self else { return false }
                return self.acceptsInput(url, for: kind)
            },
            applySelection: { [weak self] acceptedURLs in
                self?.applySelectedSources(acceptedURLs, for: kind)
            }
        )
    }

    func handleFileImportResult(_ result: Result<[URL], Error>, for selectedTab: ConverterTab) {
        switch result {
        case .success(let urls):
            let selected = uniqueStandardizedURLs(urls)
            guard !selected.isEmpty else { return }
            guard let kind = mediaKind(for: selectedTab) else { return }
            applyImportedSources(selected, for: kind)
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }
}
