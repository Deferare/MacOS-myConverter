import Combine
import Foundation

extension ContentViewModel.MediaKind {
    func assignSelection(_ urls: [URL], in viewModel: ContentViewModel) {
        viewModel.objectWillChange.send()
        synchronizeSourceSecurityScope(for: urls, in: viewModel)
        setSourceURL(urls.first, in: viewModel)
        setQueuedSourceURLs(Array(urls.dropFirst()), in: viewModel)
    }
}
