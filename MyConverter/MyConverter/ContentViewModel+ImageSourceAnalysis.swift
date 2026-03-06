import Foundation

extension ContentViewModel {
    func applySelectedImageSources(_ urls: [URL]) {
        applySelectedSources(urls, for: .image)
    }

    func analyzeImageSourceCompatibility(for urls: [URL]) {
        let primarySourceID = uniqueStandardizedURLs(urls).first.map(sourceIdentifier(for:))
        var primaryFrameCount = 0
        var primaryHasAlpha = false

        analyzeMediaSourceSelection(
            for: .image,
            urls: urls,
            availableFormatsKeyPath: \.availableImageOutputFormats,
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output format is available for the selected files.",
            onCapability: { source, capabilities in
                let sourceID = self.sourceIdentifier(for: source)
                if sourceID == primarySourceID {
                    primaryFrameCount = capabilities.frameCount
                    primaryHasAlpha = capabilities.hasAlpha
                }
            },
            onFormatsResolved: { resolvedFormats in
                self.imageSourceFrameCount = primaryFrameCount
                self.imageSourceHasAlpha = primaryHasAlpha

                self.applyResolvedOutputFormats(
                    resolvedFormats,
                    formatDescriptor: self.imageOutputFormatDescriptor(),
                    persistSettings: self.persistCurrentImageSettingsIfNeeded
                )
            }
        )
    }
}
