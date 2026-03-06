import Foundation

extension ContentViewModel {
    func analyzeSourceCompatibility(for urls: [URL]) {
        analyzeMediaSourceSelection(
            for: .video,
            urls: urls,
            availableFormatsKeyPath: \.availableOutputFormats,
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { VideoFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output container is available for the selected files.",
            onFormatsResolved: { resolvedFormats in
                self.applyResolvedOutputFormats(
                    resolvedFormats,
                    formatDescriptor: self.videoOutputFormatDescriptor(),
                    postSelectionUpdate: self.refreshVideoCodecOptions,
                    persistSettings: self.persistCurrentSettingsIfNeeded
                )
            }
        )
    }
}
