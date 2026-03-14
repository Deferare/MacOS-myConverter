import Foundation

extension ContentViewModel {
    private var defaultSuggestedOutputDirectory: URL {
        #if os(iOS)
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #else
        FileManager.default.homeDirectoryForCurrentUser
        #endif
    }

    func abbreviatedOutputDirectoryPath(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}

extension ContentViewModel.MediaKind {
    func selectedOutputDestinationHandle(in viewModel: ContentViewModel) -> OutputDestinationHandle? {
        if let handle = viewModel.securityScopeState.outputDestinationHandleByKind[self] {
            return handle
        }
        return selectedOutputDirectoryURL(in: viewModel).map { OutputDestinationHandle(url: $0) }
    }

    func setSelectedOutputDestinationHandle(
        _ handle: OutputDestinationHandle?,
        in viewModel: ContentViewModel
    ) {
        viewModel.securityScopeState.outputDestinationHandleByKind[self] = handle
        setSelectedOutputDirectoryURL(handle?.url, in: viewModel)
    }

    func selectedOutputDirectoryURL(in viewModel: ContentViewModel) -> URL? {
        if let handle = viewModel.securityScopeState.outputDestinationHandleByKind[self] {
            return handle.url
        }
        return viewModel[keyPath: outputDirectoryURLKeyPath]
    }

    func setSelectedOutputDirectoryURL(_ url: URL?, in viewModel: ContentViewModel) {
        let previousHandle = viewModel.securityScopeState.outputDestinationHandleByKind[self]
        if previousHandle?.url.path != url?.path {
            viewModel.securityScopeState.outputDestinationHandleByKind[self] = nil
        }
        viewModel.synchronizeOutputDirectorySecurityScope(for: url, kind: self)
        viewModel[keyPath: outputDirectoryURLKeyPath] = url
    }

    func hasSelectedOutputDirectory(in viewModel: ContentViewModel) -> Bool {
        selectedOutputDirectoryURL(in: viewModel) != nil
    }

    @discardableResult
    func chooseOutputDirectory(in viewModel: ContentViewModel) async -> Bool {
        let snapshot = mediaStateSnapshot(in: viewModel)
        let suggestedDirectory = selectedOutputDirectoryURL(in: viewModel)
            ?? snapshot.selectedSourceURLs.first?.deletingLastPathComponent()
            ?? viewModel.defaultSuggestedOutputDirectory

        guard let handle = await viewModel.services.outputDestinationCoordinator.chooseOutputDestination(
            suggestedDirectory: suggestedDirectory,
            outputLabel: outputLabel,
            fileCount: max(snapshot.selectedFileCount, 1)
        ) else {
            return false
        }

        setSelectedOutputDestinationHandle(handle, in: viewModel)
        return true
    }
}
