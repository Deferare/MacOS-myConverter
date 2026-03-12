import Foundation

extension ContentViewModel {
    func synchronizeSourceSecurityScope(for urls: [URL], kind: MediaKind) {
        let standardizedURLs = uniqueStandardizedURLs(urls)
        let newPaths = Set(standardizedURLs.map(\.path))
        let previousPaths = securityScopeState.pathsByKind[kind] ?? []

        let addedPaths = newPaths.subtracting(previousPaths)
        let removedPaths = previousPaths.subtracting(newPaths)

        for url in standardizedURLs where addedPaths.contains(url.path) {
            retainSourceSecurityScope(for: url)
        }

        for path in removedPaths {
            releaseSourceSecurityScope(forPath: path)
        }

        securityScopeState.pathsByKind[kind] = newPaths
    }

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

    func synchronizeOutputDirectorySecurityScope(for url: URL?, kind: MediaKind) {
        let previousPath = securityScopeState.outputDirectoryPathByKind[kind]
        let newPath = url?.path

        guard previousPath != newPath else { return }

        if let url {
            retainSourceSecurityScope(for: url)
        }

        if let previousPath {
            releaseSourceSecurityScope(forPath: previousPath)
        }

        securityScopeState.outputDirectoryPathByKind[kind] = newPath
    }
}
