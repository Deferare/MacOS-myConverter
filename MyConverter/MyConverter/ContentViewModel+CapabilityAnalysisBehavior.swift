import Foundation

extension ContentViewModel.MediaKind {
    private struct SourceAnalysisBehavior {
        let analyzeSelectionCompatibility: (ContentViewModel, [URL]) -> Void
    }

    private static let sourceAnalysisBehaviorByKind: [Self: SourceAnalysisBehavior] = [
        .video: SourceAnalysisBehavior { viewModel, urls in
            Self.video.analyzeSourceCompatibility(
                in: viewModel,
                urls: urls,
                formatDescriptor: ContentViewModel.videoOutputFormatDescriptor,
                resolvePreparedCapability: { selection in
                    guard selection.count == 1,
                          let sourceURL = selection.first,
                          let prepared = await viewModel.prepareSelectedSingleVideoSelectionIfNeeded(
                            for: sourceURL
                          ) else {
                        return nil
                    }

                    return (sourceURL, prepared.preparedSourceContext.sourceCapabilities)
                },
                fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                warningMessage: { $0.warningMessage },
                errorMessage: { $0.errorMessage },
                formatNormalizedID: { $0.normalizedID },
                deduplicatedAndSorted: { VideoFormatOption.deduplicatedAndSorted($0) },
                noCommonFormatsMessage: "No common output container is available for the selected files.",
                onFormatsResolved: { resolvedFormats in
                    viewModel.applyResolvedOutputFormats(
                        resolvedFormats,
                        formatDescriptor: ContentViewModel.videoOutputFormatDescriptor,
                        postSelectionUpdate: {
                            Self.video.refreshCodecOptions(in: viewModel)
                        },
                        persistSettings: {
                            Self.video.persistCurrentSourceSettingsIfNeeded(in: viewModel)
                        }
                    )
                }
            )
        },
        .image: SourceAnalysisBehavior { viewModel, urls in
            let primarySourceID = ContentViewModelSupport.uniqueStandardizedURLs(urls)
                .first
                .map(viewModel.sourceIdentifier(for:))
            var primaryFrameCount = 0
            var primaryHasAlpha = false

            Self.image.analyzeSourceCompatibility(
                in: viewModel,
                urls: urls,
                formatDescriptor: ContentViewModel.imageOutputFormatDescriptor,
                fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                warningMessage: { $0.warningMessage },
                errorMessage: { $0.errorMessage },
                formatNormalizedID: { $0.normalizedID },
                deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
                noCommonFormatsMessage: "No common output format is available for the selected files.",
                onCapability: { source, capabilities in
                    guard viewModel.sourceIdentifier(for: source) == primarySourceID else { return }
                    primaryFrameCount = capabilities.frameCount
                    primaryHasAlpha = capabilities.hasAlpha
                },
                onFormatsResolved: { resolvedFormats in
                    viewModel.updateState(
                        \.imageRuntimeState,
                        value: \.sourceFrameCount,
                        to: primaryFrameCount
                    )
                    viewModel.updateState(
                        \.imageRuntimeState,
                        value: \.sourceHasAlpha,
                        to: primaryHasAlpha
                    )
                    viewModel.applyResolvedOutputFormats(
                        resolvedFormats,
                        formatDescriptor: ContentViewModel.imageOutputFormatDescriptor,
                        persistSettings: {
                            Self.image.persistCurrentSourceSettingsIfNeeded(in: viewModel)
                        }
                    )
                }
            )
        },
        .audio: SourceAnalysisBehavior { viewModel, urls in
            Self.audio.analyzeSourceCompatibility(
                in: viewModel,
                urls: urls,
                formatDescriptor: ContentViewModel.audioOutputFormatDescriptor,
                fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                warningMessage: { $0.warningMessage },
                errorMessage: { $0.errorMessage },
                formatNormalizedID: { $0.normalizedID },
                deduplicatedAndSorted: { AudioFormatOption.deduplicatedAndSorted($0) },
                noCommonFormatsMessage: "No common audio output format is available for the selected files.",
                onFormatsResolved: { resolvedFormats in
                    viewModel.applyResolvedOutputFormats(
                        resolvedFormats,
                        formatDescriptor: ContentViewModel.audioOutputFormatDescriptor,
                        postSelectionUpdate: {
                            Self.audio.refreshCodecOptions(in: viewModel)
                        },
                        persistSettings: {
                            Self.audio.persistCurrentSourceSettingsIfNeeded(in: viewModel)
                        }
                    )
                }
            )
        }
    ]

    private var sourceAnalysisBehavior: SourceAnalysisBehavior {
        Self.sourceAnalysisBehaviorByKind[self] ?? Self.sourceAnalysisBehaviorByKind[.video]!
    }

    func analyzeSelectionCompatibility(in viewModel: ContentViewModel, urls: [URL]) {
        sourceAnalysisBehavior.analyzeSelectionCompatibility(viewModel, urls)
    }
}
