import Foundation

struct IndexedCapabilityResult<Capability: Sendable>: Sendable {
    let index: Int
    let source: URL
    let capability: Capability
}

struct AggregatedSourceCapabilities<Capability: Sendable, Format: Sendable>: Sendable {
    var orderedResults: [IndexedCapabilityResult<Capability>] = []
    var commonFormats: [Format] = []
    var warnings: [String] = []
    var errors: [String] = []

    nonisolated init(
        orderedResults: [IndexedCapabilityResult<Capability>] = [],
        commonFormats: [Format] = [],
        warnings: [String] = [],
        errors: [String] = []
    ) {
        self.orderedResults = orderedResults
        self.commonFormats = commonFormats
        self.warnings = warnings
        self.errors = errors
    }
}

extension ContentViewModel {
    struct SourceAnalysisSelectionHandlers<Capability: Sendable, Format: Sendable> {
        let onCapability: (URL, Capability) -> Void
        let onFormatsResolved: ([Format]) -> Void
    }

    struct SourceAnalysisCapabilityObserver<Capability: Sendable> {
        let onCapability: (URL, Capability) -> Void
        let prepareForResolvedFormats: (ContentViewModel) -> Void
    }

    struct SourceAnalysisStateDescriptor<Format: Sendable> {
        let kind: MediaKind
        let analysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
        let isAnalyzing: ReferenceWritableKeyPath<ContentViewModel, Bool>
        let availableFormats: ReferenceWritableKeyPath<ContentViewModel, [Format]>
        let warningMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let errorMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let resetForEmptySelection: (ContentViewModel) -> Void
    }

    struct SourceAnalysisDescriptor<Capability: Sendable, Format: Sendable> {
        let state: SourceAnalysisStateDescriptor<Format>
        let fetchCapabilities: @Sendable (URL) async -> Capability
        let availableFormats: @Sendable (Capability) -> [Format]
        let warningMessage: @Sendable (Capability) -> String?
        let errorMessage: @Sendable (Capability) -> String?
        let formatNormalizedID: @Sendable (Format) -> String
        let deduplicatedAndSorted: @Sendable ([Format]) -> [Format]
        let noCommonFormatsMessage: String
        let buildSelectionHandlers: (ContentViewModel, [URL]) -> SourceAnalysisSelectionHandlers<Capability, Format>
    }

    struct CapabilitySummaryInput<Capability: Sendable, Format: Sendable> {
        let kind: MediaKind
        let availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>
        let fetchCapabilities: @Sendable (URL) async -> Capability
        let availableFormats: @Sendable (Capability) -> [Format]
        let warningMessage: @Sendable (Capability) -> String?
        let errorMessage: @Sendable (Capability) -> String?
        let formatNormalizedID: @Sendable (Format) -> String
        let deduplicatedAndSorted: @Sendable ([Format]) -> [Format]
        let noCommonFormatsMessage: String
        let buildSelectionHandlers: (
            ContentViewModel,
            [URL]
        ) -> SourceAnalysisSelectionHandlers<Capability, Format>
    }

    static func makeSourceAnalysisDescriptor<Capability: Sendable, Format: Sendable>(
        kind: MediaKind,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        fetchCapabilities: @escaping @Sendable (URL) async -> Capability,
        availableFormats: @escaping @Sendable (Capability) -> [Format],
        warningMessage: @escaping @Sendable (Capability) -> String?,
        errorMessage: @escaping @Sendable (Capability) -> String?,
        formatNormalizedID: @escaping @Sendable (Format) -> String,
        deduplicatedAndSorted: @escaping @Sendable ([Format]) -> [Format],
        noCommonFormatsMessage: String,
        buildSelectionHandlers: @escaping (ContentViewModel, [URL]) -> SourceAnalysisSelectionHandlers<Capability, Format>
    ) -> SourceAnalysisDescriptor<Capability, Format> {
        SourceAnalysisDescriptor(
            state: Self.sourceAnalysisStateDescriptor(
                for: kind,
                availableFormatsKeyPath: availableFormatsKeyPath
            ),
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

    static func makeCapabilitySummaryDescriptor<Capability: Sendable, Format: Sendable>(
        _ input: CapabilitySummaryInput<Capability, Format>
    ) -> SourceAnalysisDescriptor<Capability, Format> {
        Self.makeSourceAnalysisDescriptor(
            kind: input.kind,
            availableFormatsKeyPath: input.availableFormatsKeyPath,
            fetchCapabilities: input.fetchCapabilities,
            availableFormats: input.availableFormats,
            warningMessage: input.warningMessage,
            errorMessage: input.errorMessage,
            formatNormalizedID: input.formatNormalizedID,
            deduplicatedAndSorted: input.deduplicatedAndSorted,
            noCommonFormatsMessage: input.noCommonFormatsMessage,
            buildSelectionHandlers: input.buildSelectionHandlers
        )
    }

    static func makeResolvedOutputSelectionHandlers<Capability: Sendable, Format: Sendable>(
        persistKind: MediaKind,
        formatDescriptor: @escaping (ContentViewModel) -> OutputFormatDescriptor<Format>,
        capabilityObserver: @escaping (
            ContentViewModel,
            [URL]
        ) -> SourceAnalysisCapabilityObserver<Capability> = { _, _ in
            SourceAnalysisCapabilityObserver(
                onCapability: { _, _ in },
                prepareForResolvedFormats: { _ in }
            )
        },
        postSelectionUpdate: @escaping (ContentViewModel) -> Void = { _ in }
    ) -> (ContentViewModel, [URL]) -> SourceAnalysisSelectionHandlers<Capability, Format> {
        { viewModel, urls in
            let observer = capabilityObserver(viewModel, urls)
            return SourceAnalysisSelectionHandlers(
                onCapability: observer.onCapability,
                onFormatsResolved: { resolvedFormats in
                    observer.prepareForResolvedFormats(viewModel)
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

    static func sourceAnalysisStateDescriptor<Format: Sendable>(
        for kind: MediaKind,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>
    ) -> SourceAnalysisStateDescriptor<Format> {
        let descriptor = Self.mediaStateDescriptor(for: kind)
        return SourceAnalysisStateDescriptor(
            kind: kind,
            analysisTask: descriptor.analysisTask,
            isAnalyzing: descriptor.isAnalyzing,
            availableFormats: availableFormatsKeyPath,
            warningMessage: descriptor.compatibilityWarningMessage,
            errorMessage: descriptor.compatibilityErrorMessage,
            resetForEmptySelection: { viewModel in
                viewModel.setMediaStateValue(using: descriptor, \.isAnalyzing, to: false)
                viewModel[keyPath: availableFormatsKeyPath] = []
                viewModel.resetCompatibilityState(for: kind)
            }
        )
    }

    func primarySelectedSourceID(from urls: [URL]) -> String? {
        uniqueStandardizedURLs(urls).first.map(sourceIdentifier(for:))
    }

    static func makeImageSourceCapabilityObserver()
        -> (ContentViewModel, [URL]) -> SourceAnalysisCapabilityObserver<ImageSourceCapabilities> {
        { viewModel, urls in
            let primarySourceID = viewModel.primarySelectedSourceID(from: urls)
            var primaryFrameCount = 0
            var primaryHasAlpha = false

            return SourceAnalysisCapabilityObserver(
                onCapability: { source, capabilities in
                    guard viewModel.sourceIdentifier(for: source) == primarySourceID else { return }
                    primaryFrameCount = capabilities.frameCount
                    primaryHasAlpha = capabilities.hasAlpha
                },
                prepareForResolvedFormats: { resolvedViewModel in
                    resolvedViewModel.imageSourceFrameCount = primaryFrameCount
                    resolvedViewModel.imageSourceHasAlpha = primaryHasAlpha
                }
            )
        }
    }

    func selectedSourceIDs(for kind: MediaKind) -> [String] {
        selectedSourceURLs(for: kind).map(sourceIdentifier(for:))
    }

    func analyzeSourceCompatibility<Capability: Sendable, Format: Sendable>(
        for urls: [URL],
        using descriptor: SourceAnalysisDescriptor<Capability, Format>
    ) {
        let handlers = descriptor.buildSelectionHandlers(self, urls)

        analyzeSourceSelection(
            state: descriptor.state,
            urls: urls,
            selectedSourceIDs: {
                self.selectedSourceIDs(for: descriptor.state.kind)
            },
            fetchCapabilities: descriptor.fetchCapabilities,
            availableFormats: descriptor.availableFormats,
            warningMessage: descriptor.warningMessage,
            errorMessage: descriptor.errorMessage,
            intersect: { lhs, rhs in
                ContentViewModelSupport.intersectFormats(lhs, rhs, normalizedID: descriptor.formatNormalizedID)
            },
            deduplicatedAndSorted: descriptor.deduplicatedAndSorted,
            noCommonFormatsMessage: descriptor.noCommonFormatsMessage,
            onCapability: handlers.onCapability,
            onFormatsResolved: handlers.onFormatsResolved
        )
    }

    func applyResolvedOutputFormats<Format>(
        _ resolvedFormats: [Format],
        formatDescriptor: OutputFormatDescriptor<Format>,
        postSelectionUpdate: () -> Void = {},
        persistSettings: () -> Void
    ) {
        let selectedFormat = outputFormatValue(using: formatDescriptor, \.selectedFormat)
        let resolvedSelection = resolvedSelectedFormat(
            current: selectedFormat,
            options: resolvedFormats,
            formatNormalizedID: formatDescriptor.formatNormalizedID,
            preferredSelection: formatDescriptor.preferredSelection
        )

        if let selected = resolvedSelection {
            self[keyPath: formatDescriptor.selectedFormat] = selected
        }

        postSelectionUpdate()
        persistSettings()
    }

    func applySourceAnalysisResolution<Format>(
        using state: SourceAnalysisStateDescriptor<Format>,
        resolvedFormats: [Format],
        warningMessage: String?,
        errorMessage: String?
    ) {
        self[keyPath: state.isAnalyzing] = false
        self[keyPath: state.availableFormats] = resolvedFormats
        self[keyPath: state.warningMessage] = warningMessage
        self[keyPath: state.errorMessage] = errorMessage
    }

    nonisolated static func aggregateSourceCapabilities<Capability: Sendable, Format: Sendable>(
        for selection: [URL],
        fetchCapabilities: @escaping @Sendable (URL) async -> Capability,
        availableFormats: @escaping @Sendable (Capability) -> [Format],
        warningMessage: @escaping @Sendable (Capability) -> String?,
        errorMessage: @escaping @Sendable (Capability) -> String?,
        intersect: @escaping @Sendable ([Format], [Format]) -> [Format]
    ) async -> AggregatedSourceCapabilities<Capability, Format>? {
        var isInitialized = false
        var aggregated = AggregatedSourceCapabilities<Capability, Format>()
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
                aggregated.orderedResults.append(result)
                let source = result.source
                let capabilities = result.capability

                let formats = availableFormats(capabilities)
                if isInitialized {
                    aggregated.commonFormats = intersect(aggregated.commonFormats, formats)
                } else {
                    aggregated.commonFormats = formats
                    isInitialized = true
                }

                if let warning = warningMessage(capabilities) {
                    aggregated.warnings.append(
                        ContentViewModelSupport.labeledCapabilityMessage(
                            warning,
                            for: source,
                            totalCount: selection.count
                        )
                    )
                }
                if let error = errorMessage(capabilities) {
                    aggregated.errors.append(
                        ContentViewModelSupport.labeledCapabilityMessage(
                            error,
                            for: source,
                            totalCount: selection.count
                        )
                    )
                }
            }
        }

        guard !Task.isCancelled else { return nil }
        return aggregated
    }

    func analyzeSourceSelection<Capability: Sendable, Format: Sendable>(
        state: SourceAnalysisStateDescriptor<Format>,
        urls: [URL],
        selectedSourceIDs: @escaping () -> [String],
        fetchCapabilities: @escaping @Sendable (URL) async -> Capability,
        availableFormats: @escaping @Sendable (Capability) -> [Format],
        warningMessage: @escaping @Sendable (Capability) -> String?,
        errorMessage: @escaping @Sendable (Capability) -> String?,
        intersect: @escaping @Sendable ([Format], [Format]) -> [Format],
        deduplicatedAndSorted: @escaping @Sendable ([Format]) -> [Format],
        noCommonFormatsMessage: String,
        onCapability: ((URL, Capability) -> Void)? = nil,
        onFormatsResolved: @escaping ([Format]) -> Void
    ) {
        let selection = uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(sourceIdentifier(for:))
        guard !selection.isEmpty else {
            state.resetForEmptySelection(self)
            return
        }

        cancelTask(at: state.analysisTask)
        self[keyPath: state.isAnalyzing] = true
        self[keyPath: state.analysisTask] = Task { [weak self] in
            guard let self else { return }
            if state.kind == .video,
               selection.count == 1,
               let sourceURL = selection.first,
               let prepared = await prepareSelectedSingleVideoSelectionIfNeeded(for: sourceURL),
               let capability = prepared.preparedSourceContext.sourceCapabilities as? Capability {
                guard !Task.isCancelled else { return }
                guard selectedSourceIDs() == expectedSourceIDs else { return }

                onCapability?(sourceURL, capability)
                let resolvedFormats = deduplicatedAndSorted(availableFormats(capability))
                let joinedWarnings = joinedCapabilityMessages([
                    warningMessage(capability)
                ].compactMap { $0 })

                let joinedErrors: String?
                if let capabilityError = errorMessage(capability) {
                    joinedErrors = capabilityError
                } else if selection.count > 1 && resolvedFormats.isEmpty {
                    joinedErrors = noCommonFormatsMessage
                } else {
                    joinedErrors = nil
                }

                applySourceAnalysisResolution(
                    using: state,
                    resolvedFormats: resolvedFormats,
                    warningMessage: joinedWarnings,
                    errorMessage: joinedErrors
                )

                onFormatsResolved(resolvedFormats)
                return
            }

            let aggregated = await detachedTaskValue(priority: .userInitiated) {
                await Self.aggregateSourceCapabilities(
                    for: selection,
                    fetchCapabilities: fetchCapabilities,
                    availableFormats: availableFormats,
                    warningMessage: warningMessage,
                    errorMessage: errorMessage,
                    intersect: intersect
                )
            }

            guard let aggregated else {
                return
            }
            guard !Task.isCancelled else { return }
            guard selectedSourceIDs() == expectedSourceIDs else { return }

            aggregated.orderedResults.forEach { result in
                onCapability?(result.source, result.capability)
            }

            let resolvedFormats = deduplicatedAndSorted(aggregated.commonFormats)
            let joinedWarnings = self.joinedCapabilityMessages(aggregated.warnings)
            let joinedErrors: String?
            if let resolvedErrors = self.joinedCapabilityMessages(aggregated.errors) {
                joinedErrors = resolvedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                joinedErrors = noCommonFormatsMessage
            } else {
                joinedErrors = nil
            }

            self.applySourceAnalysisResolution(
                using: state,
                resolvedFormats: resolvedFormats,
                warningMessage: joinedWarnings,
                errorMessage: joinedErrors
            )

            onFormatsResolved(resolvedFormats)
        }
    }
}
