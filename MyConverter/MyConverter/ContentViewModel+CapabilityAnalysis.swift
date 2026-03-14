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
    func primarySelectedSourceID(from urls: [URL]) -> String? {
        uniqueStandardizedURLs(urls).first.map(sourceIdentifier(for:))
    }

    func selectedSourceIDs(for kind: MediaKind) -> [String] {
        mediaStateSnapshot(for: kind).selectedSourceURLs.map(sourceIdentifier(for:))
    }

    func analyzeSourceCompatibility<Capability: Sendable, Format: Sendable>(
        for urls: [URL],
        kind: MediaKind,
        formatDescriptor: OutputFormatDescriptor<Format>,
        resolvePreparedCapability: (@Sendable ([URL]) async -> (URL, Capability)?)? = nil,
        fetchCapabilities: @escaping @Sendable (URL) async -> Capability,
        availableFormats: @escaping @Sendable (Capability) -> [Format],
        warningMessage: @escaping @Sendable (Capability) -> String?,
        errorMessage: @escaping @Sendable (Capability) -> String?,
        formatNormalizedID: @escaping @Sendable (Format) -> String,
        deduplicatedAndSorted: @escaping @Sendable ([Format]) -> [Format],
        noCommonFormatsMessage: String,
        onCapability: @escaping (URL, Capability) -> Void = { _, _ in },
        onFormatsResolved: @escaping ([Format]) -> Void
    ) {
        let stateDescriptor = kind.mediaStateDescriptor

        analyzeSourceSelection(
            urls: urls,
            kind: kind,
            stateDescriptor: stateDescriptor,
            formatDescriptor: formatDescriptor,
            selectedSourceIDs: {
                self.selectedSourceIDs(for: kind)
            },
            resolvePreparedCapability: resolvePreparedCapability,
            fetchCapabilities: fetchCapabilities,
            availableFormats: availableFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage,
            formatNormalizedID: formatNormalizedID,
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
        applyAvailableOutputFormats(resolvedFormats, using: formatDescriptor) {
            postSelectionUpdate()
            persistSettings()
        }
    }

    func applySourceAnalysisResolution<Format>(
        for kind: MediaKind,
        formatDescriptor: OutputFormatDescriptor<Format>,
        resolvedFormats: [Format],
        warningMessage: String?,
        errorMessage: String?
    ) {
        let stateDescriptor = kind.mediaStateDescriptor
        self[keyPath: stateDescriptor.isAnalyzing] = false
        self[keyPath: formatDescriptor.availableFormats] = resolvedFormats
        self[keyPath: stateDescriptor.compatibilityWarningMessage] = warningMessage
        self[keyPath: stateDescriptor.compatibilityErrorMessage] = errorMessage
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
        kind: MediaKind,
        stateDescriptor: MediaStateDescriptor,
        formatDescriptor: OutputFormatDescriptor<Format>,
        selectedSourceIDs: @escaping () -> [String],
        resolvePreparedCapability: (@Sendable ([URL]) async -> (URL, Capability)?)? = nil,
        fetchCapabilities: @escaping @Sendable (URL) async -> Capability,
        availableFormats: @escaping @Sendable (Capability) -> [Format],
        warningMessage: @escaping @Sendable (Capability) -> String?,
        errorMessage: @escaping @Sendable (Capability) -> String?,
        formatNormalizedID: @escaping @Sendable (Format) -> String,
        deduplicatedAndSorted: @escaping @Sendable ([Format]) -> [Format],
        noCommonFormatsMessage: String,
        onCapability: ((URL, Capability) -> Void)? = nil,
        onFormatsResolved: @escaping ([Format]) -> Void
    ) {
        let selection = uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(sourceIdentifier(for:))
        guard !selection.isEmpty else {
            self[keyPath: stateDescriptor.isAnalyzing] = false
            self[keyPath: formatDescriptor.availableFormats] = []
            resetCompatibilityState(for: kind)
            return
        }

        cancelTask(at: stateDescriptor.analysisTask)
        self[keyPath: stateDescriptor.isAnalyzing] = true
        self[keyPath: stateDescriptor.analysisTask] = Task { [weak self] in
            guard let self else { return }
            if let resolvePreparedCapability,
               let (sourceURL, capability) = await resolvePreparedCapability(selection) {
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
                    for: kind,
                    formatDescriptor: formatDescriptor,
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
                    intersect: { lhs, rhs in
                        ContentViewModelSupport.intersectFormats(
                            lhs,
                            rhs,
                            normalizedID: formatNormalizedID
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
                for: kind,
                formatDescriptor: formatDescriptor,
                resolvedFormats: resolvedFormats,
                warningMessage: joinedWarnings,
                errorMessage: joinedErrors
            )

            onFormatsResolved(resolvedFormats)
        }
    }

}

extension ContentViewModel.MediaKind {
    private struct SourceAnalysisBehavior {
        let analyzeSelectionCompatibility: (ContentViewModel, [URL]) -> Void
    }

    private static let sourceAnalysisBehaviorByKind: [Self: SourceAnalysisBehavior] = [
        .video: SourceAnalysisBehavior { viewModel, urls in
            viewModel.analyzeSourceCompatibility(
                for: urls,
                kind: .video,
                formatDescriptor: ContentViewModel.videoOutputFormatDescriptor,
                resolvePreparedCapability: { selection in
                    guard selection.count == 1,
                          let sourceURL = selection.first,
                          let prepared = await viewModel.prepareSelectedSingleVideoSelectionIfNeeded(
                            for: sourceURL
                          ) else {
                        return nil
                    }

                    return (sourceURL, prepared.preparedSourceContext.sourceCapabilities)
                },
                fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                warningMessage: { $0.warningMessage },
                errorMessage: { $0.errorMessage },
                formatNormalizedID: { $0.normalizedID },
                deduplicatedAndSorted: { VideoFormatOption.deduplicatedAndSorted($0) },
                noCommonFormatsMessage: "No common output container is available for the selected files.",
                onFormatsResolved: { resolvedFormats in
                    viewModel.applyResolvedOutputFormats(
                        resolvedFormats,
                        formatDescriptor: ContentViewModel.videoOutputFormatDescriptor,
                        postSelectionUpdate: {
                            viewModel.refreshVideoCodecOptions()
                        },
                        persistSettings: {
                            viewModel.persistCurrentSourceSettingsIfNeeded(for: .video)
                        }
                    )
                }
            )
        },
        .image: SourceAnalysisBehavior { viewModel, urls in
            let primarySourceID = viewModel.primarySelectedSourceID(from: urls)
            var primaryFrameCount = 0
            var primaryHasAlpha = false

            viewModel.analyzeSourceCompatibility(
                for: urls,
                kind: .image,
                formatDescriptor: ContentViewModel.imageOutputFormatDescriptor,
                fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                warningMessage: { $0.warningMessage },
                errorMessage: { $0.errorMessage },
                formatNormalizedID: { $0.normalizedID },
                deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
                noCommonFormatsMessage: "No common output format is available for the selected files.",
                onCapability: { source, capabilities in
                    guard viewModel.sourceIdentifier(for: source) == primarySourceID else { return }
                    primaryFrameCount = capabilities.frameCount
                    primaryHasAlpha = capabilities.hasAlpha
                },
                onFormatsResolved: { resolvedFormats in
                    viewModel.updateState(
                        \.imageRuntimeState,
                        value: \.sourceFrameCount,
                        to: primaryFrameCount
                    )
                    viewModel.updateState(
                        \.imageRuntimeState,
                        value: \.sourceHasAlpha,
                        to: primaryHasAlpha
                    )
                    viewModel.applyResolvedOutputFormats(
                        resolvedFormats,
                        formatDescriptor: ContentViewModel.imageOutputFormatDescriptor,
                        persistSettings: {
                            viewModel.persistCurrentSourceSettingsIfNeeded(for: .image)
                        }
                    )
                }
            )
        },
        .audio: SourceAnalysisBehavior { viewModel, urls in
            viewModel.analyzeSourceCompatibility(
                for: urls,
                kind: .audio,
                formatDescriptor: ContentViewModel.audioOutputFormatDescriptor,
                fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                warningMessage: { $0.warningMessage },
                errorMessage: { $0.errorMessage },
                formatNormalizedID: { $0.normalizedID },
                deduplicatedAndSorted: { AudioFormatOption.deduplicatedAndSorted($0) },
                noCommonFormatsMessage: "No common audio output format is available for the selected files.",
                onFormatsResolved: { resolvedFormats in
                    viewModel.applyResolvedOutputFormats(
                        resolvedFormats,
                        formatDescriptor: ContentViewModel.audioOutputFormatDescriptor,
                        postSelectionUpdate: {
                            viewModel.refreshAudioCodecOptions()
                        },
                        persistSettings: {
                            viewModel.persistCurrentSourceSettingsIfNeeded(for: .audio)
                        }
                    )
                }
            )
        }
    ]

    private var sourceAnalysisBehavior: SourceAnalysisBehavior {
        Self.sourceAnalysisBehaviorByKind[self] ?? Self.sourceAnalysisBehaviorByKind[.video]!
    }

    func analyzeSelectionCompatibility(in viewModel: ContentViewModel, urls: [URL]) {
        sourceAnalysisBehavior.analyzeSelectionCompatibility(viewModel, urls)
    }
}
