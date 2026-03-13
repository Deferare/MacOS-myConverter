import Foundation

extension ContentViewModel {
    private static let audioSourceAnalysisDescriptorValue = makeCapabilitySummaryDescriptor(
        CapabilitySummaryInput(
            kind: .audio,
            availableFormatsKeyPath: \.availableAudioOutputFormats,
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { AudioFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common audio output format is available for the selected files.",
            buildSelectionHandlers: makeResolvedOutputSelectionHandlers(
                persistKind: .audio,
                formatDescriptor: { $0.audioOutputFormatDescriptor() },
                postSelectionUpdate: { $0.refreshAudioCodecOptions() }
            )
        )
    )

    func audioSourceAnalysisDescriptor() -> SourceAnalysisDescriptor<AudioSourceCapabilities, AudioFormatOption> {
        Self.audioSourceAnalysisDescriptorValue
    }
}
