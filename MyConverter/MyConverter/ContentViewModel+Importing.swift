import AppKit
import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    func preferredImportTypes(for selectedTab: ConverterTab) -> [UTType] {
        switch selectedTab {
        case .video:
            let mkvType = UTType(filenameExtension: "mkv")
            return [.movie, .video, mkvType].compactMap { $0 }
        case .image:
            return [.image]
        case .audio:
            return [.audio, .audiovisualContent]
        case .about:
            return [.item]
        }
    }

    func requestFileImport() {
        isImporting = true
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

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        handleVideoDrop(providers: providers)
    }

    func handleMediaDrop(
        providers: [NSItemProvider],
        accept: @escaping (URL) -> Bool,
        applySelection: @escaping @MainActor ([URL]) -> Void
    ) -> Bool {
        handleDroppedFiles(providers: providers, accept: accept, onResolvedURLs: applySelection)
    }

    func handleVideoDrop(providers: [NSItemProvider]) -> Bool {
        handleMediaDrop(providers: providers, accept: isVideoInputURL) { [weak self] urls in
            self?.applySelectedVideoSources(urls)
        }
    }

    func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        handleMediaDrop(providers: providers, accept: isImageInputURL) { [weak self] urls in
            self?.applySelectedImageSources(urls)
        }
    }

    func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
        handleMediaDrop(providers: providers, accept: isAudioInputURL) { [weak self] urls in
            self?.applySelectedAudioSources(urls)
        }
    }

    func handleDroppedFiles(
        providers: [NSItemProvider],
        accept: @escaping (URL) -> Bool,
        onResolvedURLs: @escaping @MainActor ([URL]) -> Void
    ) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var resolvedURLs: [URL] = []

        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }

                var finalURL: URL?

                if let data = item as? Data {
                    finalURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    finalURL = url
                }

                guard let finalURL else { return }

                lock.lock()
                resolvedURLs.append(finalURL)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let unique = self.uniqueStandardizedURLs(resolvedURLs)
            let accepted = unique.filter(accept)
            guard !accepted.isEmpty else { return }

            Task { @MainActor in
                onResolvedURLs(accepted)
            }
        }

        return true
    }
}
