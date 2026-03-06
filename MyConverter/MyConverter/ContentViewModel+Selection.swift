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
}
