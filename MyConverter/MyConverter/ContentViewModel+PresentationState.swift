import SwiftUI

extension ContentViewModel {
    struct VideoFormPresentationState: Equatable {
        let isConverting: Bool
        let settings: VideoEncodingSelectionState

        init(viewModel: ContentViewModel) {
            isConverting = viewModel.videoRuntimeState.media.isConverting
            settings = viewModel.videoEncodingSelectionState
        }
    }

    struct ImageFormPresentationState: Equatable {
        let isConverting: Bool
        let selectedOutputFormat: ImageFormatOption
        let selectedResolution: ResolutionOption
        let selectedQuality: ImageQualityOption
        let selectedPNGCompressionLevel: PNGCompressionLevelOption
        let preserveAnimation: Bool
        let outputFormatOptions: [ImageFormatOption]
        let shouldShowImageQualityOption: Bool
        let shouldShowPNGCompressionOption: Bool
        let shouldShowPreserveAnimationOption: Bool
        let hintMessage: String?

        init(viewModel: ContentViewModel) {
            isConverting = viewModel.imageRuntimeState.media.isConverting
            selectedOutputFormat = viewModel.imageOptionsState.selectedOutputFormat
            selectedResolution = viewModel.imageOptionsState.selectedResolution
            selectedQuality = viewModel.imageOptionsState.selectedQuality
            selectedPNGCompressionLevel = viewModel.imageOptionsState.selectedPNGCompressionLevel
            preserveAnimation = viewModel.imageOptionsState.preserveAnimation
            outputFormatOptions = viewModel.imageOutputFormatOptions
            shouldShowImageQualityOption = viewModel.shouldShowImageQualityOption
            shouldShowPNGCompressionOption = viewModel.shouldShowPNGCompressionOption
            shouldShowPreserveAnimationOption = viewModel.shouldShowPreserveAnimationOption
            hintMessage = viewModel.hintMessage(for: .image)
        }
    }

    struct AudioFormPresentationState: Equatable {
        let isConverting: Bool
        let selectedOutputFormat: AudioFormatOption
        let audioSettings: AudioEncodingSelectionState
        let outputFormatOptions: [AudioFormatOption]
        let hintMessage: String?

        init(viewModel: ContentViewModel) {
            isConverting = viewModel.audioRuntimeState.media.isConverting
            selectedOutputFormat = viewModel.audioOptionsState.selectedOutputFormat
            audioSettings = viewModel.audioOutputEncodingSelectionState
            outputFormatOptions = viewModel.audioOutputFormatOptions
            hintMessage = viewModel.hintMessage(for: .audio)
        }
    }

    func binding<Value>(
        get: @escaping @MainActor @Sendable () -> Value,
        set: @escaping @MainActor @Sendable (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: get, set: set)
    }

    func binding<Value>(
        to keyPath: ReferenceWritableKeyPath<ContentViewModel, Value>
    ) -> Binding<Value> {
        binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

}
