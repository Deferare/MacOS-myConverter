import Foundation

extension ContentViewModel {
    func assignVideoSelection(_ urls: [URL]) {
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: \.sourceURL,
            queuedKeyPath: \.queuedSourceURLs
        )
    }

    func assignImageSelection(_ urls: [URL]) {
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: \.imageSourceURL,
            queuedKeyPath: \.queuedImageSourceURLs
        )
    }

    func assignAudioSelection(_ urls: [URL]) {
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: \.audioSourceURL,
            queuedKeyPath: \.queuedAudioSourceURLs
        )
    }
}
