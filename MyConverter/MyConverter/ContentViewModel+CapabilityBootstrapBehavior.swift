import Foundation

extension ContentViewModel.MediaKind {
    private struct CapabilityBootstrapBehavior: Sendable {
        let applyPlaceholderCapabilities: @MainActor @Sendable (ContentViewModel) -> Void
        let warmedDefaultCapability: @Sendable () -> ContentViewModel.WarmedDefaultCapability
    }

    nonisolated private static let capabilityBootstrapBehaviorByKind: [Self: CapabilityBootstrapBehavior] = [
        .video: CapabilityBootstrapBehavior(
            applyPlaceholderCapabilities: { viewModel in
                viewModel.applyAvailableOutputFormats(
                    ContentViewModelSupport.placeholderVideoFormats(),
                    using: ContentViewModel.videoOutputFormatDescriptor
                )
                Self.video.applyPlaceholderCodecOptions(to: viewModel)
            },
            warmedDefaultCapability: {
                let warmedFormats = VideoConversionEngine.defaultOutputFormats()
                return ContentViewModel.WarmedDefaultCapability { viewModel in
                    Self.video.applyWarmedOutputFormatsIfIdle(
                        warmedFormats,
                        in: viewModel,
                        formatDescriptor: ContentViewModel.videoOutputFormatDescriptor,
                        postApply: {
                            Self.video.refreshCodecOptions(in: viewModel)
                        }
                    )
                }
            }
        ),
        .image: CapabilityBootstrapBehavior(
            applyPlaceholderCapabilities: { viewModel in
                viewModel.applyAvailableOutputFormats(
                    ContentViewModelSupport.placeholderImageFormats(),
                    using: ContentViewModel.imageOutputFormatDescriptor
                )
            },
            warmedDefaultCapability: {
                let warmedFormats = ImageConversionEngine.defaultOutputFormats()
                return ContentViewModel.WarmedDefaultCapability { viewModel in
                    Self.image.applyWarmedOutputFormatsIfIdle(
                        warmedFormats,
                        in: viewModel,
                        formatDescriptor: ContentViewModel.imageOutputFormatDescriptor
                    )
                }
            }
        ),
        .audio: CapabilityBootstrapBehavior(
            applyPlaceholderCapabilities: { viewModel in
                viewModel.applyAvailableOutputFormats(
                    ContentViewModelSupport.placeholderAudioFormats(),
                    using: ContentViewModel.audioOutputFormatDescriptor
                )
                Self.audio.applyPlaceholderCodecOptions(to: viewModel)
            },
            warmedDefaultCapability: {
                let warmedFormats = VideoConversionEngine.defaultAudioOutputFormats()
                return ContentViewModel.WarmedDefaultCapability { viewModel in
                    Self.audio.applyWarmedOutputFormatsIfIdle(
                        warmedFormats,
                        in: viewModel,
                        formatDescriptor: ContentViewModel.audioOutputFormatDescriptor,
                        postApply: {
                            Self.audio.refreshCodecOptions(in: viewModel)
                        }
                    )
                }
            }
        )
    ]

    nonisolated private var capabilityBootstrapBehavior: CapabilityBootstrapBehavior {
        Self.capabilityBootstrapBehaviorByKind[self] ?? Self.capabilityBootstrapBehaviorByKind[.video]!
    }

    func applyPlaceholderCapabilities(to viewModel: ContentViewModel) {
        capabilityBootstrapBehavior.applyPlaceholderCapabilities(viewModel)
    }

    func applyWarmedOutputFormatsIfIdle<Format>(
        _ warmedFormats: [Format],
        in viewModel: ContentViewModel,
        formatDescriptor: ContentViewModel.OutputFormatDescriptor<Format>,
        postApply: () -> Void = {}
    ) {
        guard !hasSelectedSource(in: viewModel),
              !isAnalyzing(in: viewModel) else {
            return
        }

        viewModel.applyAvailableOutputFormats(
            warmedFormats,
            using: formatDescriptor,
            postApply: postApply
        )
    }

    nonisolated func warmedDefaultCapability() -> ContentViewModel.WarmedDefaultCapability {
        capabilityBootstrapBehavior.warmedDefaultCapability()
    }
}
