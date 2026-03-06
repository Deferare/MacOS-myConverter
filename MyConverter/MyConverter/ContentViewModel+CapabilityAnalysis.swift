import Foundation

extension ContentViewModel {
    struct IndexedCapabilityResult<Capability: Sendable>: Sendable {
        let index: Int
        let source: URL
        let capability: Capability
    }

    struct AggregatedSourceCapabilities<Format> {
        var commonFormats: [Format] = []
        var warnings: [String] = []
        var errors: [String] = []
    }

    struct SourceAnalysisSelectionHandlers<Capability: Sendable, Format> {
        let onCapability: (URL, Capability) -> Void
        let onFormatsResolved: ([Format]) -> Void
    }

    struct SourceAnalysisDescriptor<Capability: Sendable, Format> {
        let kind: MediaKind
        let availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>
        let fetchCapabilities: @Sendable (URL) async -> Capability
        let availableFormats: (Capability) -> [Format]
        let warningMessage: (Capability) -> String?
        let errorMessage: (Capability) -> String?
        let formatNormalizedID: (Format) -> String
        let deduplicatedAndSorted: ([Format]) -> [Format]
        let noCommonFormatsMessage: String
        let buildSelectionHandlers: (ContentViewModel, [URL]) -> SourceAnalysisSelectionHandlers<Capability, Format>
    }

    func makeSourceAnalysisDescriptor<Capability: Sendable, Format>(
        kind: MediaKind,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        fetchCapabilities: @escaping @Sendable (URL) async -> Capability,
        availableFormats: @escaping (Capability) -> [Format],
        warningMessage: @escaping (Capability) -> String?,
        errorMessage: @escaping (Capability) -> String?,
        formatNormalizedID: @escaping (Format) -> String,
        deduplicatedAndSorted: @escaping ([Format]) -> [Format],
        noCommonFormatsMessage: String,
        buildSelectionHandlers: @escaping (ContentViewModel, [URL]) -> SourceAnalysisSelectionHandlers<Capability, Format>
    ) -> SourceAnalysisDescriptor<Capability, Format> {
        SourceAnalysisDescriptor(
            kind: kind,
            availableFormatsKeyPath: availableFormatsKeyPath,
            fetchCapabilities: fetchCapabilities,
            availableFormats: availableFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage,
            formatNormalizedID: formatNormalizedID,
            deduplicatedAndSorted: deduplicatedAndSorted,
            noCommonFormatsMessage: noCommonFormatsMessage,
            buildSelectionHandlers: buildSelectionHandlers
        )
    }

    func makeResolvedOutputSelectionHandlers<Capability: Sendable, Format>(
        persistKind: MediaKind,
        formatDescriptor: @escaping (ContentViewModel) -> OutputFormatDescriptor<Format>,
        postSelectionUpdate: @escaping (ContentViewModel) -> Void = { _ in }
    ) -> (ContentViewModel, [URL]) -> SourceAnalysisSelectionHandlers<Capability, Format> {
        { viewModel, _ in
            SourceAnalysisSelectionHandlers(
                onCapability: { _, _ in },
                onFormatsResolved: { resolvedFormats in
                    viewModel.applyResolvedOutputFormats(
                        resolvedFormats,
                        formatDescriptor: formatDescriptor(viewModel),
                        postSelectionUpdate: {
                            postSelectionUpdate(viewModel)
                        },
                        persistSettings: {
                            viewModel.persistCurrentSourceSettingsIfNeeded(for: persistKind)
                        }
                    )
                }
            )
        }
    }

    func makeImageSourceSelectionHandlers()
        -> (ContentViewModel, [URL]) -> SourceAnalysisSelectionHandlers<ImageSourceCapabilities, ImageFormatOption> {
        { viewModel, urls in
            let primarySourceID = viewModel.uniqueStandardizedURLs(urls)
                .first
                .map(viewModel.sourceIdentifier(for:))
            var primaryFrameCount = 0
            var primaryHasAlpha = false

            return SourceAnalysisSelectionHandlers(
                onCapability: { source, capabilities in
                    guard viewModel.sourceIdentifier(for: source) == primarySourceID else { return }
                    primaryFrameCount = capabilities.frameCount
                    primaryHasAlpha = capabilities.hasAlpha
                },
                onFormatsResolved: { resolvedFormats in
                    viewModel.imageSourceFrameCount = primaryFrameCount
                    viewModel.imageSourceHasAlpha = primaryHasAlpha
                    viewModel.applyResolvedOutputFormats(
                        resolvedFormats,
                        formatDescriptor: viewModel.imageOutputFormatDescriptor(),
                        persistSettings: {
                            viewModel.persistCurrentSourceSettingsIfNeeded(for: .image)
                        }
                    )
                }
            )
        }
    }

    func selectedSourceIDs(for kind: MediaKind) -> [String] {
        selectedSourceURLs(for: kind).map(sourceIdentifier(for:))
    }

    func resetAnalysisStateForEmptySelection<Format>(
        for kind: MediaKind,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>
    ) {
        let descriptor = mediaStateDescriptor(for: kind)
        self[keyPath: descriptor.isAnalyzing] = false
        self[keyPath: availableFormatsKeyPath] = []
        resetCompatibilityState(for: kind)
    }

    func analyzeSourceCompatibility<Capability: Sendable, Format>(
        for urls: [URL],
        using descriptor: SourceAnalysisDescriptor<Capability, Format>
    ) {
        let handlers = descriptor.buildSelectionHandlers(self, urls)

        analyzeMediaSourceSelection(
            for: descriptor.kind,
            urls: urls,
            availableFormatsKeyPath: descriptor.availableFormatsKeyPath,
            fetchCapabilities: descriptor.fetchCapabilities,
            availableFormats: descriptor.availableFormats,
            warningMessage: descriptor.warningMessage,
            errorMessage: descriptor.errorMessage,
            formatNormalizedID: descriptor.formatNormalizedID,
            deduplicatedAndSorted: descriptor.deduplicatedAndSorted,
            noCommonFormatsMessage: descriptor.noCommonFormatsMessage,
            onCapability: handlers.onCapability,
            onFormatsResolved: handlers.onFormatsResolved
        )
    }

    func analyzeMediaSourceSelection<Capability: Sendable, Format>(
        for kind: MediaKind,
        urls: [URL],
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        fetchCapabilities: @escaping @Sendable (URL) async -> Capability,
        availableFormats: @escaping (Capability) -> [Format],
        warningMessage: @escaping (Capability) -> String?,
        errorMessage: @escaping (Capability) -> String?,
        formatNormalizedID: @escaping (Format) -> String,
        deduplicatedAndSorted: @escaping ([Format]) -> [Format],
        noCommonFormatsMessage: String,
        onCapability: ((URL, Capability) -> Void)? = nil,
        onEmptySelection: (() -> Void)? = nil,
        onFormatsResolved: @escaping ([Format]) -> Void
    ) {
        let descriptor = mediaStateDescriptor(for: kind)

        analyzeSourceSelection(
            urls: urls,
            analysisTaskKeyPath: descriptor.analysisTask,
            isAnalyzingKeyPath: descriptor.isAnalyzing,
            availableFormatsKeyPath: availableFormatsKeyPath,
            warningMessageKeyPath: descriptor.compatibilityWarningMessage,
            errorMessageKeyPath: descriptor.compatibilityErrorMessage,
            selectedSourceIDs: {
                self.selectedSourceIDs(for: kind)
            },
            resetForEmptySelection: {
                self.resetAnalysisStateForEmptySelection(
                    for: kind,
                    availableFormatsKeyPath: availableFormatsKeyPath
                )
                onEmptySelection?()
            },
            fetchCapabilities: fetchCapabilities,
            availableFormats: availableFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage,
            intersect: { lhs, rhs in
                ContentViewModelSupport.intersectFormats(lhs, rhs, normalizedID: formatNormalizedID)
            },
            deduplicatedAndSorted: deduplicatedAndSorted,
            noCommonFormatsMessage: noCommonFormatsMessage,
            onCapability: onCapability,
            onFormatsResolved: onFormatsResolved
        )
    }

    func applyResolvedOutputFormats<Format>(
        _ resolvedFormats: [Format],
        formatDescriptor: OutputFormatDescriptor<Format>,
        postSelectionUpdate: () -> Void = {},
        persistSettings: () -> Void
    ) {
        if let first = resolvedFormats.first,
           !resolvedFormats.contains(where: {
               formatDescriptor.formatNormalizedID($0) ==
                   formatDescriptor.formatNormalizedID(self[keyPath: formatDescriptor.selectedFormat])
           }) {
            self[keyPath: formatDescriptor.selectedFormat] = first
        }

        ensureSelectedOutputFormatIsAvailable(using: formatDescriptor)
        postSelectionUpdate()
        persistSettings()
    }

    func aggregateSourceCapabilities<Capability: Sendable, Format>(
        for selection: [URL],
        fetchCapabilities: @escaping @Sendable (URL) async -> Capability,
        availableFormats: (Capability) -> [Format],
        warningMessage: (Capability) -> String?,
        errorMessage: (Capability) -> String?,
        intersect: ([Format], [Format]) -> [Format],
        onCapability: ((URL, Capability) -> Void)? = nil
    ) async -> AggregatedSourceCapabilities<Format>? {
        var isInitialized = false
        var aggregated = AggregatedSourceCapabilities<Format>()
        let maxConcurrentAnalyses = max(1, min(4, ProcessInfo.processInfo.activeProcessorCount))

        for batchStart in stride(from: 0, to: selection.count, by: maxConcurrentAnalyses) {
            guard !Task.isCancelled else { return nil }
            let batchEnd = min(batchStart + maxConcurrentAnalyses, selection.count)
            let batch = Array(selection[batchStart..<batchEnd])

            let results = await withTaskGroup(
                of: IndexedCapabilityResult<Capability>?.self,
                returning: [IndexedCapabilityResult<Capability>].self
            ) { group in
                for (offset, source) in batch.enumerated() {
                    let index = batchStart + offset
                    group.addTask {
                        guard !Task.isCancelled else { return nil }
                        let capability = await SecurityScopedResourceAccess.withAccess(to: source) {
                            await fetchCapabilities(source)
                        }
                        guard !Task.isCancelled else { return nil }
                        return IndexedCapabilityResult(
                            index: index,
                            source: source,
                            capability: capability
                        )
                    }
                }

                var batchResults: [IndexedCapabilityResult<Capability>] = []
                for await result in group {
                    guard let result else { continue }
                    batchResults.append(result)
                }

                return batchResults.sorted { $0.index < $1.index }
            }

            for result in results {
                let source = result.source
                let capabilities = result.capability
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
        }

        guard !Task.isCancelled else { return nil }
        return aggregated
    }

    func analyzeSourceSelection<Capability: Sendable, Format>(
        urls: [URL],
        analysisTaskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        isAnalyzingKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        warningMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        selectedSourceIDs: @escaping () -> [String],
        resetForEmptySelection: () -> Void,
        fetchCapabilities: @escaping @Sendable (URL) async -> Capability,
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

        cancelTask(at: analysisTaskKeyPath)
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
