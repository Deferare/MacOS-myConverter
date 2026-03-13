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
        let selectedAudioEncoder: AudioEncoderOption
        let selectedAudioMode: AudioModeOption
        let selectedSampleRate: SampleRateOption
        let selectedAudioBitRate: AudioBitRateOption
        let outputFormatOptions: [VideoFormatOption]
        let videoEncoderOptions: [VideoEncoderOption]
        let audioEncoderOptions: [AudioEncoderOption]
        let shouldShowVideoEncoderOption: Bool
        let shouldShowAudioSettings: Bool
        let shouldShowGIFPlaybackSpeedOption: Bool
        let shouldShowVideoBitRateOption: Bool
        let shouldShowAudioSampleRateOption: Bool
        let shouldShowAudioBitRateOption: Bool

        init(viewModel: ContentViewModel) {
            isConverting = viewModel.isConverting
            selectedOutputFormat = viewModel.selectedOutputFormat
            selectedVideoEncoder = viewModel.selectedVideoEncoder
            selectedResolution = viewModel.selectedResolution
            selectedFrameRate = viewModel.selectedFrameRate
            selectedGIFPlaybackSpeed = viewModel.selectedGIFPlaybackSpeed
            selectedVideoBitRate = viewModel.selectedVideoBitRate
            customVideoBitRate = viewModel.customVideoBitRate
            selectedAudioEncoder = viewModel.selectedAudioEncoder
            selectedAudioMode = viewModel.selectedAudioMode
            selectedSampleRate = viewModel.selectedSampleRate
            selectedAudioBitRate = viewModel.selectedAudioBitRate
            outputFormatOptions = viewModel.outputFormatOptions
            videoEncoderOptions = viewModel.videoEncoderOptions
            audioEncoderOptions = viewModel.audioEncoderOptions
            shouldShowVideoEncoderOption = viewModel.shouldShowVideoEncoderOption
            shouldShowAudioSettings = viewModel.shouldShowAudioSettings
            shouldShowGIFPlaybackSpeedOption = viewModel.shouldShowGIFPlaybackSpeedOption
            shouldShowVideoBitRateOption = viewModel.shouldShowVideoBitRateOption
            shouldShowAudioSampleRateOption = viewModel.shouldShowAudioSampleRateOption
            shouldShowAudioBitRateOption = viewModel.shouldShowAudioBitRateOption
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
            isConverting = viewModel.isImageConverting
            selectedOutputFormat = viewModel.selectedImageOutputFormat
            selectedResolution = viewModel.selectedImageResolution
            selectedQuality = viewModel.selectedImageQuality
            selectedPNGCompressionLevel = viewModel.selectedPNGCompressionLevel
            preserveAnimation = viewModel.preserveImageAnimation
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
        let selectedOutputEncoder: AudioEncoderOption
        let selectedOutputMode: AudioModeOption
        let selectedOutputSampleRate: SampleRateOption
        let selectedOutputBitRate: AudioBitRateOption
        let outputFormatOptions: [AudioFormatOption]
        let audioOutputEncoderOptions: [AudioEncoderOption]
        let shouldShowAudioOutputSampleRateOption: Bool
        let shouldShowAudioOutputBitRateOption: Bool
        let hintMessage: String?

        init(viewModel: ContentViewModel) {
            isConverting = viewModel.isAudioConverting
            selectedOutputFormat = viewModel.selectedAudioOutputFormat
            selectedOutputEncoder = viewModel.selectedAudioOutputEncoder
            selectedOutputMode = viewModel.selectedAudioOutputMode
            selectedOutputSampleRate = viewModel.selectedAudioOutputSampleRate
            selectedOutputBitRate = viewModel.selectedAudioOutputBitRate
            outputFormatOptions = viewModel.audioOutputFormatOptions
            audioOutputEncoderOptions = viewModel.audioOutputEncoderOptions
            shouldShowAudioOutputSampleRateOption = viewModel.shouldShowAudioOutputSampleRateOption
            shouldShowAudioOutputBitRateOption = viewModel.shouldShowAudioOutputBitRateOption
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
