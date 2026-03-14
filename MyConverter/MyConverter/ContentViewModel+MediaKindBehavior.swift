import Foundation

extension ContentViewModel.MediaKind {
    private struct MediaBehavior {
        let descriptor: ContentViewModel.MediaStateDescriptor
        let performConversion: @MainActor (ContentViewModel) async -> Void
        let analyzeSelectedSources: (ContentViewModel, [URL]) -> Void
        let resetCompatibilityMetadata: (ContentViewModel) -> Void
    }

    private static let mediaBehaviorByKind: [Self: MediaBehavior] = [
        .video: MediaBehavior(
            descriptor: ContentViewModel.videoStateDescriptor,
            performConversion: { viewModel in
                await viewModel.performVideoConversion()
            },
            analyzeSelectedSources: { viewModel, urls in
                Self.video.analyzeSelectionCompatibility(in: viewModel, urls: urls)
            },
            resetCompatibilityMetadata: { _ in }
        ),
        .image: MediaBehavior(
            descriptor: ContentViewModel.imageStateDescriptor,
            performConversion: { viewModel in
                await viewModel.performImageConversion()
            },
            analyzeSelectedSources: { viewModel, urls in
                Self.image.analyzeSelectionCompatibility(in: viewModel, urls: urls)
            },
            resetCompatibilityMetadata: { viewModel in
                ContentViewModel.resetImageCompatibilityMetadata(viewModel)
            }
        ),
        .audio: MediaBehavior(
            descriptor: ContentViewModel.audioStateDescriptor,
            performConversion: { viewModel in
                await viewModel.performAudioConversion()
            },
            analyzeSelectedSources: { viewModel, urls in
                Self.audio.analyzeSelectionCompatibility(in: viewModel, urls: urls)
            },
            resetCompatibilityMetadata: { _ in }
        )
    ]

    private var mediaBehavior: MediaBehavior {
        Self.mediaBehaviorByKind[self] ?? Self.mediaBehaviorByKind[.video]!
    }

    var mediaStateDescriptor: ContentViewModel.MediaStateDescriptor {
        mediaBehavior.descriptor
    }

    @MainActor
    func performConversion(in viewModel: ContentViewModel) async {
        await mediaBehavior.performConversion(viewModel)
    }

    func analyzeSelectedSources(_ urls: [URL], in viewModel: ContentViewModel) {
        mediaBehavior.analyzeSelectedSources(viewModel, urls)
    }

    func resetCompatibilityMetadata(in viewModel: ContentViewModel) {
        mediaBehavior.resetCompatibilityMetadata(viewModel)
    }
}
