#if os(iOS)
import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    func handleMediaDrop(
        providers: [NSItemProvider],
        accept: @escaping (URL) -> Bool,
        applySelection: @escaping @MainActor ([URL]) -> Void
    ) -> Bool {
        handleDroppedFiles(providers: providers, accept: accept, onResolvedURLs: applySelection)
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

                let finalURL: URL?
                if let data = item as? Data {
                    finalURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    finalURL = url
                } else {
                    finalURL = nil
                }

                guard let finalURL else { return }

                lock.lock()
                resolvedURLs.append(finalURL)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            let accepted = ContentViewModelSupport.uniqueStandardizedURLs(resolvedURLs)
                .filter(accept)
            guard !accepted.isEmpty else { return }

            Task { @MainActor in
                onResolvedURLs(accepted)
            }
        }

        return true
    }
}

extension ContentViewModel.MediaKind {
    func handleDrop(
        providers: [NSItemProvider],
        in viewModel: ContentViewModel
    ) -> Bool {
        viewModel.handleMediaDrop(
            providers: providers,
            accept: acceptsInput(_:),
            applySelection: { [weak viewModel] urls in
                guard let viewModel else { return }
                self.applyImportedSources(urls, in: viewModel)
            }
        )
    }
}
#endif
