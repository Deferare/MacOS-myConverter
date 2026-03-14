import Foundation

extension ContentViewModel.MediaKind {
    func resetSourceAnalysisState<Format>(
        in viewModel: ContentViewModel,
        formatDescriptor: ContentViewModel.OutputFormatDescriptor<Format>
    ) {
        setAnalyzing(false, in: viewModel)
        viewModel[keyPath: formatDescriptor.availableFormats] = []
        resetCompatibilityState(in: viewModel)
    }

    func applySourceAnalysisResolution<Format>(
        in viewModel: ContentViewModel,
        formatDescriptor: ContentViewModel.OutputFormatDescriptor<Format>,
        resolvedFormats: [Format],
        warningMessage: String?,
        errorMessage: String?
    ) {
        setAnalyzing(false, in: viewModel)
        viewModel[keyPath: formatDescriptor.availableFormats] = resolvedFormats
        setCompatibilityMessages(
            warningMessage: warningMessage,
            errorMessage: errorMessage,
            in: viewModel
        )
    }

    func analyzeSourceCompatibility<Capability: Sendable, Format: Sendable>(
        in viewModel: ContentViewModel,
        urls: [URL],
        formatDescriptor: ContentViewModel.OutputFormatDescriptor<Format>,
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
        analyzeSourceSelection(
            in: viewModel,
            urls: urls,
            formatDescriptor: formatDescriptor,
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

    func analyzeSourceSelection<Capability: Sendable, Format: Sendable>(
        in viewModel: ContentViewModel,
        urls: [URL],
        formatDescriptor: ContentViewModel.OutputFormatDescriptor<Format>,
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
        let selection = ContentViewModelSupport.uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(viewModel.sourceIdentifier(for:))
        guard !selection.isEmpty else {
            resetSourceAnalysisState(in: viewModel, formatDescriptor: formatDescriptor)
            return
        }

        cancelAnalysisTask(in: viewModel)
        setAnalyzing(true, in: viewModel)
        setAnalysisTask(Task { [weak viewModel] in
            guard let viewModel else { return }
            if let resolvePreparedCapability,
               let (sourceURL, capability) = await resolvePreparedCapability(selection) {
                guard !Task.isCancelled else { return }
                guard self.selectedSourceIDs(in: viewModel) == expectedSourceIDs else { return }

                onCapability?(sourceURL, capability)
                let resolvedFormats = deduplicatedAndSorted(availableFormats(capability))
                let joinedWarnings = ContentViewModelSupport.joinedCapabilityMessages([
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

                self.applySourceAnalysisResolution(
                    in: viewModel,
                    formatDescriptor: formatDescriptor,
                    resolvedFormats: resolvedFormats,
                    warningMessage: joinedWarnings,
                    errorMessage: joinedErrors
                )

                onFormatsResolved(resolvedFormats)
                return
            }

            let aggregated = await detachedTaskValue(priority: .userInitiated) {
                await ContentViewModel.aggregateSourceCapabilities(
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
            guard self.selectedSourceIDs(in: viewModel) == expectedSourceIDs else { return }

            aggregated.orderedResults.forEach { result in
                onCapability?(result.source, result.capability)
            }

            let resolvedFormats = deduplicatedAndSorted(aggregated.commonFormats)
            let joinedWarnings = ContentViewModelSupport.joinedCapabilityMessages(aggregated.warnings)
            let joinedErrors: String?
            if let resolvedErrors = ContentViewModelSupport.joinedCapabilityMessages(aggregated.errors) {
                joinedErrors = resolvedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                joinedErrors = noCommonFormatsMessage
            } else {
                joinedErrors = nil
            }

            self.applySourceAnalysisResolution(
                in: viewModel,
                formatDescriptor: formatDescriptor,
                resolvedFormats: resolvedFormats,
                warningMessage: joinedWarnings,
                errorMessage: joinedErrors
            )

            onFormatsResolved(resolvedFormats)
        }, in: viewModel)
    }
}
