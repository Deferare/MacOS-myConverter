import Foundation

extension ContentViewModel {
    func assignSelection(_ urls: [URL], for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: descriptor.sourceURL,
            queuedKeyPath: descriptor.queuedSourceURLs
        )
    }

    func assignVideoSelection(_ urls: [URL]) {
        assignSelection(urls, for: .video)
    }

    func assignImageSelection(_ urls: [URL]) {
        assignSelection(urls, for: .image)
    }

    func assignAudioSelection(_ urls: [URL]) {
        assignSelection(urls, for: .audio)
    }
}
