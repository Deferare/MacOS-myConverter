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

    struct SourceAnalysisDescriptor<Capability: Sendable, Format: Sendable> {
        let kind: MediaKind
        let analysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>
        let isAnalyzing: ReferenceWritableKeyPath<ContentViewModel, Bool>
        let availableFormats: ReferenceWritableKeyPath<ContentViewModel, [Format]>
        let warningMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let errorMessage: ReferenceWritableKeyPath<ContentViewModel, String?>
        let resetForEmptySelection: (ContentViewModel) -> Void
        let fetchCapabilities: @Sendable (URL) async -> Capability
        let availableFormatsForCapability: @Sendable (Capability) -> [Format]
        let warningMessageForCapability: @Sendable (Capability) -> String?
        let errorMessageForCapability: @Sendable (Capability) -> String?
        let formatNormalizedID: @Sendable (Format) -> String
        let deduplicatedAndSorted: @Sendable ([Format]) -> [Format]
        let noCommonFormatsMessage: String
        let buildSelectionHandlers: (ContentViewModel, [URL]) -> SourceAnalysisSelectionHandlers<Capability, Format>
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
        let descriptor = Self.mediaStateDescriptor(for: kind)
        return SourceAnalysisDescriptor(
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
            },
            fetchCapabilities: fetchCapabilities,
            availableFormatsForCapability: availableFormats,
            warningMessageForCapability: warningMessage,
            errorMessageForCapability: errorMessage,
            formatNormalizedID: formatNormalizedID,
            deduplicatedAndSorted: deduplicatedAndSorted,
            noCommonFormatsMessage: noCommonFormatsMessage,
            buildSelectionHandlers: buildSelectionHandlers
        )
    }

    static func makeResolvedOutputSelectionHandlers<Capability: Sendable, Format: Sendable>(
        persistKind: MediaKind,
        formatDescriptor: OutputFormatDescriptor<Format>,
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
                        formatDescriptor: formatDescriptor,
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
                    resolvedViewModel.updateState(\.imageRuntimeState, value: \.sourceFrameCount, to: primaryFrameCount)
                    resolvedViewModel.updateState(\.imageRuntimeState, value: \.sourceHasAlpha, to: primaryHasAlpha)
                }
            )
        }
    }

    func selectedSourceIDs(for kind: MediaKind) -> [String] {
        mediaStateSnapshot(for: kind).selectedSourceURLs.map(sourceIdentifier(for:))
    }

    func analyzeSourceCompatibility<Capability: Sendable, Format: Sendable>(
        for urls: [URL],
        using descriptor: SourceAnalysisDescriptor<Capability, Format>
    ) {
        let handlers = descriptor.buildSelectionHandlers(self, urls)

        analyzeSourceSelection(
            urls: urls,
            using: descriptor,
            selectedSourceIDs: {
                self.selectedSourceIDs(for: descriptor.kind)
            },
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
        formatDescriptor.applyAvailableFormats(resolvedFormats, to: self) {
            postSelectionUpdate()
            persistSettings()
        }
    }

    func applySourceAnalysisResolution<Capability: Sendable, Format: Sendable>(
        using descriptor: SourceAnalysisDescriptor<Capability, Format>,
        resolvedFormats: [Format],
        warningMessage: String?,
        errorMessage: String?
    ) {
        self[keyPath: descriptor.isAnalyzing] = false
        self[keyPath: descriptor.availableFormats] = resolvedFormats
        self[keyPath: descriptor.warningMessage] = warningMessage
        self[keyPath: descriptor.errorMessage] = errorMessage
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
        urls: [URL],
        using descriptor: SourceAnalysisDescriptor<Capability, Format>,
        selectedSourceIDs: @escaping () -> [String],
        onCapability: ((URL, Capability) -> Void)? = nil,
        onFormatsResolved: @escaping ([Format]) -> Void
    ) {
        let selection = uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(sourceIdentifier(for:))
        guard !selection.isEmpty else {
            descriptor.resetForEmptySelection(self)
            return
        }

        cancelTask(at: descriptor.analysisTask)
        self[keyPath: descriptor.isAnalyzing] = true
        self[keyPath: descriptor.analysisTask] = Task { [weak self] in
            guard let self else { return }
            if descriptor.kind == .video,
               selection.count == 1,
               let sourceURL = selection.first,
               let prepared = await prepareSelectedSingleVideoSelectionIfNeeded(for: sourceURL),
               let capability = prepared.preparedSourceContext.sourceCapabilities as? Capability {
                guard !Task.isCancelled else { return }
                guard selectedSourceIDs() == expectedSourceIDs else { return }

                onCapability?(sourceURL, capability)
                let resolvedFormats = descriptor.deduplicatedAndSorted(
                    descriptor.availableFormatsForCapability(capability)
                )
                let joinedWarnings = joinedCapabilityMessages([
                    descriptor.warningMessageForCapability(capability)
                ].compactMap { $0 })

                let joinedErrors: String?
                if let capabilityError = descriptor.errorMessageForCapability(capability) {
                    joinedErrors = capabilityError
                } else if selection.count > 1 && resolvedFormats.isEmpty {
                    joinedErrors = descriptor.noCommonFormatsMessage
                } else {
                    joinedErrors = nil
                }

                applySourceAnalysisResolution(
                    using: descriptor,
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
                    fetchCapabilities: descriptor.fetchCapabilities,
                    availableFormats: descriptor.availableFormatsForCapability,
                    warningMessage: descriptor.warningMessageForCapability,
                    errorMessage: descriptor.errorMessageForCapability,
                    intersect: { lhs, rhs in
                        ContentViewModelSupport.intersectFormats(
                            lhs,
                            rhs,
                            normalizedID: descriptor.formatNormalizedID
                        )
                    }
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

            let resolvedFormats = descriptor.deduplicatedAndSorted(aggregated.commonFormats)
            let joinedWarnings = self.joinedCapabilityMessages(aggregated.warnings)
            let joinedErrors: String?
            if let resolvedErrors = self.joinedCapabilityMessages(aggregated.errors) {
                joinedErrors = resolvedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                joinedErrors = descriptor.noCommonFormatsMessage
            } else {
                joinedErrors = nil
            }

            self.applySourceAnalysisResolution(
                using: descriptor,
                resolvedFormats: resolvedFormats,
                warningMessage: joinedWarnings,
                errorMessage: joinedErrors
            )

            onFormatsResolved(resolvedFormats)
        }
    }
}
