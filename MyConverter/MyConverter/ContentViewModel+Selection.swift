import Combine
import Foundation

extension ContentViewModel.MediaKind {
    func assignSelection(_ urls: [URL], in viewModel: ContentViewModel) {
        viewModel.objectWillChange.send()
        viewModel.synchronizeSourceSecurityScope(for: urls, kind: self)
        let descriptor = mediaStateDescriptor
        viewModel.assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: descriptor.sourceURL,
            queuedKeyPath: descriptor.queuedSourceURLs
        )
    }
}
