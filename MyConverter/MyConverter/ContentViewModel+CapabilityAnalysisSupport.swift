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
}
