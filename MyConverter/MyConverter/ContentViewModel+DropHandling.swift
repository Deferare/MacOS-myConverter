import AppKit
import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        handleDrop(providers: providers, for: .video)
    }

    func handleMediaDrop(
        providers: [NSItemProvider],
        accept: @escaping (URL) -> Bool,
        applySelection: @escaping @MainActor ([URL]) -> Void
    ) -> Bool {
        handleDroppedFiles(providers: providers, accept: accept, onResolvedURLs: applySelection)
    }

    func handleDrop(providers: [NSItemProvider], for kind: MediaKind) -> Bool {
        handleMediaDrop(
            providers: providers,
            accept: { [weak self] url in
                guard let self else { return false }
                return self.acceptsInput(url, for: kind)
            },
            applySelection: { [weak self] urls in
                self?.applySelectedSources(urls, for: kind)
            }
        )
    }

    func handleVideoDrop(providers: [NSItemProvider]) -> Bool {
        handleDrop(providers: providers, for: .video)
    }

    func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        handleDrop(providers: providers, for: .image)
    }

    func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
        handleDrop(providers: providers, for: .audio)
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
