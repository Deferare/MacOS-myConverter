import Foundation

extension ContentViewModel {
    protocol SourceCapabilitySummary {
        associatedtype Format

        var availableOutputFormats: [Format] { get }
        var warningMessage: String? { get }
        var errorMessage: String? { get }
    }

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

    struct SourceAnalysisCapabilityObserver<Capability: Sendable> {
        let onCapability: (URL, Capability) -> Void
        let prepareForResolvedFormats: (ContentViewModel) -> Void
    }

    struct SourceAnalysisStateDescriptor<Format> {
        let kind: MediaKind
        let analysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
        let isAnalyzing: ReferenceWritableKeyPath<ContentViewModel, Bool>
        let availableFormats: ReferenceWritableKeyPath<ContentViewModel, [Format]>
        let warningMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let errorMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let resetForEmptySelection: (ContentViewModel) -> Void
    }

    struct SourceAnalysisDescriptor<Capability: Sendable, Format> {
        let state: SourceAnalysisStateDescriptor<Format>
        let fetchCapabilities: @Sendable (URL) async -> Capability
        let availableFormats: (Capability) -> [Format]
        let warningMessage: (Capability) -> String?
        let errorMessage: (Capability) -> String?
        let formatNormalizedID: (Format) -> String
        let deduplicatedAndSorted: ([Format]) -> [Format]
        let noCommonFormatsMessage: String
        let buildSelectionHandlers: (ContentViewModel, [URL]) -> SourceAnalysisSelectionHandlers<Capability, Format>
    }

    struct CapabilitySummaryInput<Capability: SourceCapabilitySummary & Sendable> {
        let kind: MediaKind
        let availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Capability.Format]>
        let fetchCapabilities: @Sendable (URL) async -> Capability
        let formatNormalizedID: (Capability.Format) -> String
        let deduplicatedAndSorted: ([Capability.Format]) -> [Capability.Format]
        let noCommonFormatsMessage: String
        let buildSelectionHandlers: (
            ContentViewModel,
            [URL]
        ) -> SourceAnalysisSelectionHandlers<Capability, Capability.Format>
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
            state: sourceAnalysisStateDescriptor(
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

    func makeCapabilitySummaryDescriptor<Capability: SourceCapabilitySummary & Sendable>(
        _ input: CapabilitySummaryInput<Capability>
    ) -> SourceAnalysisDescriptor<Capability, Capability.Format> {
        makeSourceAnalysisDescriptor(
            kind: input.kind,
            availableFormatsKeyPath: input.availableFormatsKeyPath,
            fetchCapabilities: input.fetchCapabilities,
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: input.formatNormalizedID,
            deduplicatedAndSorted: input.deduplicatedAndSorted,
            noCommonFormatsMessage: input.noCommonFormatsMessage,
            buildSelectionHandlers: input.buildSelectionHandlers
        )
    }

    func makeResolvedOutputSelectionHandlers<Capability: Sendable, Format>(
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

    func sourceAnalysisStateDescriptor<Format>(
        for kind: MediaKind,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>
    ) -> SourceAnalysisStateDescriptor<Format> {
        let descriptor = mediaStateDescriptor(for: kind)
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

    func makeImageSourceCapabilityObserver()
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

    func analyzeSourceCompatibility<Capability: Sendable, Format>(
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
        state: SourceAnalysisStateDescriptor<Format>,
        urls: [URL],
        selectedSourceIDs: @escaping () -> [String],
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
            state.resetForEmptySelection(self)
            return
        }

        cancelTask(at: state.analysisTask)
        self[keyPath: state.isAnalyzing] = true
        self[keyPath: state.analysisTask] = Task { [weak self] in
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
            self[keyPath: state.isAnalyzing] = false
            self[keyPath: state.availableFormats] = resolvedFormats
            self[keyPath: state.warningMessage] = self.joinedCapabilityMessages(aggregated.warnings)

            if let joinedErrors = self.joinedCapabilityMessages(aggregated.errors) {
                self[keyPath: state.errorMessage] = joinedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                self[keyPath: state.errorMessage] = noCommonFormatsMessage
            } else {
                self[keyPath: state.errorMessage] = nil
            }

            onFormatsResolved(resolvedFormats)
        }
    }
}

extension VideoSourceCapabilities: ContentViewModel.SourceCapabilitySummary {}
extension ImageSourceCapabilities: ContentViewModel.SourceCapabilitySummary {}
extension AudioSourceCapabilities: ContentViewModel.SourceCapabilitySummary {}
