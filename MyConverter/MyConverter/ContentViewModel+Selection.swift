import Combine
import Foundation

extension ContentViewModel {
    func assignSelection(_ urls: [URL], for kind: MediaKind) {
        objectWillChange.send()
        synchronizeSourceSecurityScope(for: urls, kind: kind)
        let descriptor = mediaStateDescriptor(for: kind)
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: descriptor.sourceURL,
            queuedKeyPath: descriptor.queuedSourceURLs
        )
    }
}
