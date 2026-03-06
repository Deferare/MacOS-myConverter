import Foundation

extension ContentViewModel {
    func videoSourceAnalysisDescriptor() -> SourceAnalysisDescriptor<VideoSourceCapabilities, VideoFormatOption> {
        SourceAnalysisDescriptor(
            kind: .video,
            availableFormatsKeyPath: \.availableOutputFormats,
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { VideoFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output container is available for the selected files.",
            buildSelectionHandlers: { viewModel, _ in
                SourceAnalysisSelectionHandlers(
                    onCapability: { _, _ in },
                    onFormatsResolved: { resolvedFormats in
                        viewModel.applyResolvedOutputFormats(
                            resolvedFormats,
                            formatDescriptor: viewModel.videoOutputFormatDescriptor(),
                            postSelectionUpdate: viewModel.refreshVideoCodecOptions,
                            persistSettings: {
                                viewModel.persistCurrentSourceSettingsIfNeeded(for: .video)
                            }
                        )
                    }
                )
            }
        )
    }
}
