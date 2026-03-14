import Foundation

extension ContentViewModel {
    static let videoSourceAnalysisDescriptorValue = makeCapabilitySummaryDescriptor(
        CapabilitySummaryInput(
            kind: .video,
            availableFormatsKeyPath: \.videoRuntimeState.media.availableOutputFormats,
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { VideoFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output container is available for the selected files.",
            buildSelectionHandlers: makeResolvedOutputSelectionHandlers(
                persistKind: .video,
                formatDescriptor: videoOutputFormatDescriptorValue,
                postSelectionUpdate: { $0.refreshVideoCodecOptions() }
            )
        )
    )
}
