import Foundation

extension ContentViewModel {
    func applySelectedAudioSources(_ urls: [URL]) {
        applySelectedSources(urls, for: .audio)
    }

    func analyzeAudioSourceCompatibility(for urls: [URL]) {
        analyzeMediaSourceSelection(
            for: .audio,
            urls: urls,
            availableFormatsKeyPath: \.availableAudioOutputFormats,
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { AudioFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common audio output format is available for the selected files.",
            onFormatsResolved: { resolvedFormats in
                self.applyResolvedOutputFormats(
                    resolvedFormats,
                    formatDescriptor: self.audioOutputFormatDescriptor(),
                    postSelectionUpdate: self.refreshAudioCodecOptions,
                    persistSettings: self.persistCurrentAudioSettingsIfNeeded
                )
            }
        )
    }
}
