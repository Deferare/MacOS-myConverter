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

    func selectedOutputDestinationHandle(for kind: MediaKind) -> OutputDestinationHandle? {
        if let handle = securityScopeState.outputDestinationHandleByKind[kind] {
            return handle
        }
        return selectedOutputDirectoryURL(for: kind).map { OutputDestinationHandle(url: $0) }
    }

    func setSelectedOutputDestinationHandle(_ handle: OutputDestinationHandle?, for kind: MediaKind) {
        securityScopeState.outputDestinationHandleByKind[kind] = handle
        setSelectedOutputDirectoryURL(handle?.url, for: kind)
    }

    func selectedOutputDirectoryURL(for kind: MediaKind) -> URL? {
        if let handle = securityScopeState.outputDestinationHandleByKind[kind] {
            return handle.url
        }
        return self[keyPath: kind.descriptor.outputDirectoryURL]
    }

    func setSelectedOutputDirectoryURL(_ url: URL?, for kind: MediaKind) {
        let previousHandle = securityScopeState.outputDestinationHandleByKind[kind]
        if previousHandle?.url.path != url?.path {
            securityScopeState.outputDestinationHandleByKind[kind] = nil
        }
        synchronizeOutputDirectorySecurityScope(for: url, kind: kind)
        self[keyPath: kind.descriptor.outputDirectoryURL] = url
    }

    func hasSelectedOutputDirectory(for kind: MediaKind) -> Bool {
        selectedOutputDirectoryURL(for: kind) != nil
    }

    @discardableResult
    func chooseOutputDirectory(for kind: MediaKind) async -> Bool {
        let suggestedDirectory = selectedOutputDirectoryURL(for: kind)
            ?? selectedSourceURLs(for: kind).first?.deletingLastPathComponent()
            ?? defaultSuggestedOutputDirectory

        guard let handle = await services.outputDestinationCoordinator.chooseOutputDestination(
            suggestedDirectory: suggestedDirectory,
            outputLabel: kind.conversionMetadata.outputLabel,
            fileCount: max(selectedFileCount(for: kind), 1)
        ) else {
            return false
        }

        setSelectedOutputDestinationHandle(handle, for: kind)
        return true
    }

    func abbreviatedOutputDirectoryPath(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}
