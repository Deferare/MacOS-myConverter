import SwiftUI

extension ContentViewModel {
    struct VideoFormPresentationState: Equatable {
        let isConverting: Bool
        let selectedOutputFormat: VideoFormatOption
        let selectedVideoEncoder: VideoEncoderOption
        let selectedResolution: ResolutionOption
        let selectedFrameRate: FrameRateOption
        let selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption
        let selectedVideoBitRate: VideoBitRateOption
        let customVideoBitRate: String
        let audioSettings: AudioEncodingSelectionState
        let outputFormatOptions: [VideoFormatOption]
        let videoEncoderOptions: [VideoEncoderOption]
        let shouldShowVideoEncoderOption: Bool
        let shouldShowAudioSettings: Bool
        let shouldShowGIFPlaybackSpeedOption: Bool
        let shouldShowVideoBitRateOption: Bool

        init(viewModel: ContentViewModel) {
            isConverting = viewModel.videoRuntimeState.media.isConverting
            selectedOutputFormat = viewModel.videoOptionsState.selectedOutputFormat
            selectedVideoEncoder = viewModel.videoOptionsState.selectedVideoEncoder
            selectedResolution = viewModel.videoOptionsState.selectedResolution
            selectedFrameRate = viewModel.videoOptionsState.selectedFrameRate
            selectedGIFPlaybackSpeed = viewModel.videoOptionsState.selectedGIFPlaybackSpeed
            selectedVideoBitRate = viewModel.videoOptionsState.selectedVideoBitRate
            customVideoBitRate = viewModel.videoOptionsState.customVideoBitRate
            audioSettings = viewModel.videoAudioEncodingSelectionState
            outputFormatOptions = viewModel.outputFormatOptions
            videoEncoderOptions = viewModel.videoEncoderOptions
            shouldShowVideoEncoderOption = viewModel.shouldShowVideoEncoderOption
            shouldShowAudioSettings = viewModel.shouldShowAudioSettings
            shouldShowGIFPlaybackSpeedOption = viewModel.shouldShowGIFPlaybackSpeedOption
            shouldShowVideoBitRateOption = viewModel.shouldShowVideoBitRateOption
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
