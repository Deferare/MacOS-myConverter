import Foundation

extension ContentViewModel {
    static let imageSourceAnalysisDescriptorValue = makeCapabilitySummaryDescriptor(
        CapabilitySummaryInput(
            kind: .image,
            availableFormatsKeyPath: \.imageRuntimeState.media.availableOutputFormats,
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output format is available for the selected files.",
            buildSelectionHandlers: makeResolvedOutputSelectionHandlers(
                persistKind: .image,
                formatDescriptor: imageOutputFormatDescriptorValue,
                capabilityObserver: makeImageSourceCapabilityObserver()
            )
        )
    )
}
