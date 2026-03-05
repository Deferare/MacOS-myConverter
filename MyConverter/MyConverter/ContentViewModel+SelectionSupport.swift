import Foundation

extension ContentViewModel {
    func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        ContentViewModelSupport.uniqueStandardizedURLs(urls)
    }

    func isVideoInputURL(_ url: URL) -> Bool {
        ContentViewModelSupport.isVideoInputURL(url)
    }

    func isImageInputURL(_ url: URL) -> Bool {
        ContentViewModelSupport.isImageInputURL(url)
    }

    func isAudioInputURL(_ url: URL) -> Bool {
        ContentViewModelSupport.isAudioInputURL(url)
    }

    func cancelTask(_ task: inout Task<Void, Never>?) {
        task?.cancel()
        task = nil
    }

    func assignPrimaryAndQueuedSources(
        _ urls: [URL],
        primaryKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        queuedKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>
    ) {
        self[keyPath: primaryKeyPath] = urls.first
        self[keyPath: queuedKeyPath] = Array(urls.dropFirst())
    }

    func applySelectedSources(
        _ urls: [URL],
        cancelAnalysisTask: () -> Void,
        assignSelection: ([URL]) -> Void,
        resetState: () -> Void,
        applyStoredSettingsForSourceID: (String) -> Void,
        analyzeSelection: ([URL]) -> Void
    ) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let firstURL = uniqueURLs.first else { return }

        cancelAnalysisTask()
        assignSelection(uniqueURLs)
        resetState()

        let sourceID = sourceIdentifier(for: firstURL)
        applyStoredSettingsForSourceID(sourceID)
        analyzeSelection(uniqueURLs)
    }

    func applyStoredSettingsForSource<Settings>(
        sourceID: String,
        settingsBySourceID: [String: Settings],
        defaultSettings: @autoclosure () -> Settings,
        apply: (Settings) -> Void
    ) {
        let stored = settingsBySourceID[sourceID] ?? defaultSettings()
        apply(stored)
    }

    func removeProcessedSource(
        _ processedURL: URL,
        from selectedSourceURLs: [URL],
        assignSelection: ([URL]) -> Void,
        onSelectionEmptied: () -> Void
    ) {
        let processedID = sourceIdentifier(for: processedURL)
        let remainingSources = selectedSourceURLs.filter { sourceIdentifier(for: $0) != processedID }
        assignSelection(remainingSources)
        guard !remainingSources.isEmpty else {
            onSelectionEmptied()
            return
        }
    }

    func labeledCapabilityMessage(_ message: String, for sourceURL: URL, totalCount: Int) -> String {
        ContentViewModelSupport.labeledCapabilityMessage(message, for: sourceURL, totalCount: totalCount)
    }

    func joinedCapabilityMessages(_ messages: [String]) -> String? {
        ContentViewModelSupport.joinedCapabilityMessages(messages)
    }
}
