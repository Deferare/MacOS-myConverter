import Foundation

extension ContentViewModel {
    func audioSourceAnalysisDescriptor() -> SourceAnalysisDescriptor<AudioSourceCapabilities, AudioFormatOption> {
        SourceAnalysisDescriptor(
            kind: .audio,
            availableFormatsKeyPath: \.availableAudioOutputFormats,
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { AudioFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common audio output format is available for the selected files.",
            buildSelectionHandlers: { viewModel, _ in
                SourceAnalysisSelectionHandlers(
                    onCapability: { _, _ in },
                    onFormatsResolved: { resolvedFormats in
                        viewModel.applyResolvedOutputFormats(
                            resolvedFormats,
                            formatDescriptor: viewModel.audioOutputFormatDescriptor(),
                            postSelectionUpdate: viewModel.refreshAudioCodecOptions,
                            persistSettings: viewModel.persistCurrentAudioSettingsIfNeeded
                        )
                    }
                )
            }
        )
    }
}
