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
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
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
        let descriptor = mediaStateDescriptor(for: kind)

        analyzeSourceSelection(
            urls: urls,
            kind: kind,
            analysisTask: descriptor.analysisTask,
            isAnalyzing: descriptor.isAnalyzing,
            availableFormatsKeyPath: availableFormatsKeyPath,
            warningMessageKeyPath: descriptor.compatibilityWarningMessage,
            errorMessageKeyPath: descriptor.compatibilityErrorMessage,
            selectedSourceIDs: {
                self.selectedSourceIDs(for: kind)
            },
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
        formatDescriptor.applyAvailableFormats(resolvedFormats, to: self) {
            postSelectionUpdate()
            persistSettings()
        }
    }

    func applySourceAnalysisResolution<Format>(
        isAnalyzingKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        warningMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        resolvedFormats: [Format],
        warningMessage: String?,
        errorMessage: String?
    ) {
        self[keyPath: isAnalyzingKeyPath] = false
        self[keyPath: availableFormatsKeyPath] = resolvedFormats
        self[keyPath: warningMessageKeyPath] = warningMessage
        self[keyPath: errorMessageKeyPath] = errorMessage
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
        analysisTask: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        isAnalyzing: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        warningMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        selectedSourceIDs: @escaping () -> [String],
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
            self[keyPath: isAnalyzing] = false
            self[keyPath: availableFormatsKeyPath] = []
            resetCompatibilityState(for: kind)
            return
        }

        cancelTask(at: analysisTask)
        self[keyPath: isAnalyzing] = true
        self[keyPath: analysisTask] = Task { [weak self] in
            guard let self else { return }
            if kind == .video,
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
                    isAnalyzingKeyPath: isAnalyzing,
                    availableFormatsKeyPath: availableFormatsKeyPath,
                    warningMessageKeyPath: warningMessageKeyPath,
                    errorMessageKeyPath: errorMessageKeyPath,
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
                isAnalyzingKeyPath: isAnalyzing,
                availableFormatsKeyPath: availableFormatsKeyPath,
                warningMessageKeyPath: warningMessageKeyPath,
                errorMessageKeyPath: errorMessageKeyPath,
                resolvedFormats: resolvedFormats,
                warningMessage: joinedWarnings,
                errorMessage: joinedErrors
            )

            onFormatsResolved(resolvedFormats)
        }
    }

    func analyzeVideoSourceCompatibility(for urls: [URL]) {
        analyzeSourceCompatibility(
            for: urls,
            kind: .video,
            availableFormatsKeyPath: \.videoRuntimeState.media.availableOutputFormats,
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { VideoFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output container is available for the selected files.",
            onFormatsResolved: { [self] resolvedFormats in
                applyResolvedOutputFormats(
                    resolvedFormats,
                    formatDescriptor: Self.videoOutputFormatDescriptorValue,
                    postSelectionUpdate: {
                        refreshVideoCodecOptions()
                    },
                    persistSettings: {
                        persistCurrentSourceSettingsIfNeeded(for: .video)
                    }
                )
            }
        )
    }

    func analyzeImageSourceCompatibility(for urls: [URL]) {
        let primarySourceID = primarySelectedSourceID(from: urls)
        var primaryFrameCount = 0
        var primaryHasAlpha = false

        analyzeSourceCompatibility(
            for: urls,
            kind: .image,
            availableFormatsKeyPath: \.imageRuntimeState.media.availableOutputFormats,
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output format is available for the selected files.",
            onCapability: { [self] source, capabilities in
                guard sourceIdentifier(for: source) == primarySourceID else { return }
                primaryFrameCount = capabilities.frameCount
                primaryHasAlpha = capabilities.hasAlpha
            },
            onFormatsResolved: { [self] resolvedFormats in
                updateState(\.imageRuntimeState, value: \.sourceFrameCount, to: primaryFrameCount)
                updateState(\.imageRuntimeState, value: \.sourceHasAlpha, to: primaryHasAlpha)
                applyResolvedOutputFormats(
                    resolvedFormats,
                    formatDescriptor: Self.imageOutputFormatDescriptorValue,
                    persistSettings: {
                        persistCurrentSourceSettingsIfNeeded(for: .image)
                    }
                )
            }
        )
    }

    func analyzeAudioSourceCompatibility(for urls: [URL]) {
        analyzeSourceCompatibility(
            for: urls,
            kind: .audio,
            availableFormatsKeyPath: \.audioRuntimeState.media.availableOutputFormats,
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { AudioFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common audio output format is available for the selected files.",
            onFormatsResolved: { [self] resolvedFormats in
                applyResolvedOutputFormats(
                    resolvedFormats,
                    formatDescriptor: Self.audioOutputFormatDescriptorValue,
                    postSelectionUpdate: {
                        refreshAudioCodecOptions()
                    },
                    persistSettings: {
                        persistCurrentSourceSettingsIfNeeded(for: .audio)
                    }
                )
            }
        )
    }
}
