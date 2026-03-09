import Foundation

extension ContentViewModel {
    func imageSourceAnalysisDescriptor() -> SourceAnalysisDescriptor<ImageSourceCapabilities, ImageFormatOption> {
        makeCapabilitySummaryDescriptor(
            CapabilitySummaryInput(
                kind: .image,
                availableFormatsKeyPath: \.availableImageOutputFormats,
                fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
                formatNormalizedID: { $0.normalizedID },
                deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
                noCommonFormatsMessage: "No common output format is available for the selected files.",
                buildSelectionHandlers: makeResolvedOutputSelectionHandlers(
                    persistKind: .image,
                    formatDescriptor: { $0.imageOutputFormatDescriptor() },
                    capabilityObserver: makeImageSourceCapabilityObserver()
                )
            )
        )
    }
}
