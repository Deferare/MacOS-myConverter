import Foundation

extension ContentViewModel {
    struct AggregatedSourceCapabilities<Format> {
        var commonFormats: [Format] = []
        var warnings: [String] = []
        var errors: [String] = []
    }

    func aggregateSourceCapabilities<Capability, Format>(
        for selection: [URL],
        fetchCapabilities: @escaping (URL) async -> Capability,
        availableFormats: (Capability) -> [Format],
        warningMessage: (Capability) -> String?,
        errorMessage: (Capability) -> String?,
        intersect: ([Format], [Format]) -> [Format],
        onCapability: ((URL, Capability) -> Void)? = nil
    ) async -> AggregatedSourceCapabilities<Format>? {
        var isInitialized = false
        var aggregated = AggregatedSourceCapabilities<Format>()

        for source in selection {
            guard !Task.isCancelled else { return nil }

            let capabilities = await withSourceSecurityScope(for: source) {
                await fetchCapabilities(source)
            }
            onCapability?(source, capabilities)

            let formats = availableFormats(capabilities)
            if isInitialized {
                aggregated.commonFormats = intersect(aggregated.commonFormats, formats)
            } else {
                aggregated.commonFormats = formats
                isInitialized = true
            }

            if let warning = warningMessage(capabilities) {
                aggregated.warnings.append(labeledCapabilityMessage(warning, for: source, totalCount: selection.count))
            }
            if let error = errorMessage(capabilities) {
                aggregated.errors.append(labeledCapabilityMessage(error, for: source, totalCount: selection.count))
            }
        }

        guard !Task.isCancelled else { return nil }
        return aggregated
    }

    func analyzeSourceSelection<Capability, Format>(
        urls: [URL],
        analysisTaskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        isAnalyzingKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        warningMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        selectedSourceIDs: @escaping () -> [String],
        resetForEmptySelection: () -> Void,
        fetchCapabilities: @escaping (URL) async -> Capability,
        availableFormats: @escaping (Capability) -> [Format],
        warningMessage: @escaping (Capability) -> String?,
        errorMessage: @escaping (Capability) -> String?,
        intersect: @escaping ([Format], [Format]) -> [Format],
        deduplicatedAndSorted: @escaping ([Format]) -> [Format],
        noCommonFormatsMessage: String,
        onCapability: ((URL, Capability) -> Void)? = nil,
        onFormatsResolved: @escaping ([Format]) -> Void
    ) {
        let selection = uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(sourceIdentifier(for:))
        guard !selection.isEmpty else {
            resetForEmptySelection()
            return
        }

        self[keyPath: isAnalyzingKeyPath] = true
        self[keyPath: analysisTaskKeyPath] = Task { [weak self] in
            guard let self else { return }
            guard let aggregated = await self.aggregateSourceCapabilities(
                for: selection,
                fetchCapabilities: fetchCapabilities,
                availableFormats: availableFormats,
                warningMessage: warningMessage,
                errorMessage: errorMessage,
                intersect: intersect,
                onCapability: onCapability
            ) else {
                return
            }
            guard selectedSourceIDs() == expectedSourceIDs else { return }

            let resolvedFormats = deduplicatedAndSorted(aggregated.commonFormats)
            self[keyPath: isAnalyzingKeyPath] = false
            self[keyPath: availableFormatsKeyPath] = resolvedFormats
            self[keyPath: warningMessageKeyPath] = self.joinedCapabilityMessages(aggregated.warnings)

            if let joinedErrors = self.joinedCapabilityMessages(aggregated.errors) {
                self[keyPath: errorMessageKeyPath] = joinedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                self[keyPath: errorMessageKeyPath] = noCommonFormatsMessage
            } else {
                self[keyPath: errorMessageKeyPath] = nil
            }

            onFormatsResolved(resolvedFormats)
        }
    }
}
