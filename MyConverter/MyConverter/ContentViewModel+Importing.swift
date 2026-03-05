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

    func handleFileImportResult(_ result: Result<[URL], Error>, for selectedTab: ConverterTab) {
        switch result {
        case .success(let urls):
            let selected = uniqueStandardizedURLs(urls)
            guard !selected.isEmpty else { return }
            switch selectedTab {
            case .video:
                applyImportedSources(selected, accept: isVideoInputURL) { urls in
                    applySelectedVideoSources(urls)
                }
            case .image:
                applyImportedSources(selected, accept: isImageInputURL) { urls in
                    applySelectedImageSources(urls)
                }
            case .audio:
                applyImportedSources(selected, accept: isAudioInputURL) { urls in
                    applySelectedAudioSources(urls)
                }
            case .about:
                break
            }
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }
}
