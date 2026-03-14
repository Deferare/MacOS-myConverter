import Foundation

extension ContentViewModel {
    private func retainSourceSecurityScope(for url: URL) {
        let path = url.path
        if var existing = securityScopeState.retainedByPath[path] {
            existing.retainCount += 1
            securityScopeState.retainedByPath[path] = existing
            return
        }

        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        securityScopeState.retainedByPath[path] = RetainedSecurityScopedURL(
            url: url,
            shouldStopAccessing: shouldStopAccessing,
            retainCount: 1
        )
    }

    private func releaseSourceSecurityScope(forPath path: String) {
        guard var existing = securityScopeState.retainedByPath[path] else { return }

        existing.retainCount -= 1
        guard existing.retainCount <= 0 else {
            securityScopeState.retainedByPath[path] = existing
            return
        }

        if existing.shouldStopAccessing {
            existing.url.stopAccessingSecurityScopedResource()
        }
        securityScopeState.retainedByPath.removeValue(forKey: path)
    }
}

extension ContentViewModel.MediaKind {
    func synchronizeSourceSecurityScope(for urls: [URL], in viewModel: ContentViewModel) {
        let standardizedURLs = ContentViewModelSupport.uniqueStandardizedURLs(urls)
        let newPaths = Set(standardizedURLs.map(\.path))
        let previousPaths = viewModel.securityScopeState.pathsByKind[self] ?? []

        let addedPaths = newPaths.subtracting(previousPaths)
        let removedPaths = previousPaths.subtracting(newPaths)

        for url in standardizedURLs where addedPaths.contains(url.path) {
            viewModel.retainSourceSecurityScope(for: url)
        }

        for path in removedPaths {
            viewModel.releaseSourceSecurityScope(forPath: path)
        }

        viewModel.securityScopeState.pathsByKind[self] = newPaths
    }

    func synchronizeOutputDirectorySecurityScope(for url: URL?, in viewModel: ContentViewModel) {
        let previousPath = viewModel.securityScopeState.outputDirectoryPathByKind[self]
        let newPath = url?.path

        guard previousPath != newPath else { return }

        if let url {
            viewModel.retainSourceSecurityScope(for: url)
        }

        if let previousPath {
            viewModel.releaseSourceSecurityScope(forPath: previousPath)
        }

        viewModel.securityScopeState.outputDirectoryPathByKind[self] = newPath
    }
}
