import Foundation

extension ContentViewModel {
    func imageSourceAnalysisDescriptor() -> SourceAnalysisDescriptor<ImageSourceCapabilities, ImageFormatOption> {
        SourceAnalysisDescriptor(
            kind: .image,
            availableFormatsKeyPath: \.availableImageOutputFormats,
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output format is available for the selected files.",
            buildSelectionHandlers: { viewModel, urls in
                let primarySourceID = viewModel.uniqueStandardizedURLs(urls).first.map(viewModel.sourceIdentifier(for:))
                var primaryFrameCount = 0
                var primaryHasAlpha = false

                return SourceAnalysisSelectionHandlers(
                    onCapability: { source, capabilities in
                        let sourceID = viewModel.sourceIdentifier(for: source)
                        if sourceID == primarySourceID {
                            primaryFrameCount = capabilities.frameCount
                            primaryHasAlpha = capabilities.hasAlpha
                        }
                    },
                    onFormatsResolved: { resolvedFormats in
                        viewModel.imageSourceFrameCount = primaryFrameCount
                        viewModel.imageSourceHasAlpha = primaryHasAlpha

                        viewModel.applyResolvedOutputFormats(
                            resolvedFormats,
                            formatDescriptor: viewModel.imageOutputFormatDescriptor(),
                            persistSettings: {
                                viewModel.persistCurrentSourceSettingsIfNeeded(for: .image)
                            }
                        )
                    }
                )
            }
        )
    }
}
