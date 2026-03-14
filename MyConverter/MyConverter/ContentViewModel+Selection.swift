import Combine
import Foundation

extension ContentViewModel.MediaKind {
    func assignSelection(_ urls: [URL], in viewModel: ContentViewModel) {
        viewModel.objectWillChange.send()
        viewModel.synchronizeSourceSecurityScope(for: urls, kind: self)
        setSourceURL(urls.first, in: viewModel)
        setQueuedSourceURLs(Array(urls.dropFirst()), in: viewModel)
    }
}
