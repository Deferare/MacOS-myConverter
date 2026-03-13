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

    struct VideoFormBindings {
        let selectedOutputFormat: Binding<VideoFormatOption>
        let selectedVideoEncoder: Binding<VideoEncoderOption>
        let selectedResolution: Binding<ResolutionOption>
        let selectedFrameRate: Binding<FrameRateOption>
        let selectedGIFPlaybackSpeed: Binding<GIFPlaybackSpeedOption>
        let selectedVideoBitRate: Binding<VideoBitRateOption>
        let customVideoBitRate: Binding<String>
        let selectedAudioEncoder: Binding<AudioEncoderOption>
        let selectedAudioMode: Binding<AudioModeOption>
        let selectedSampleRate: Binding<SampleRateOption>
        let selectedAudioBitRate: Binding<AudioBitRateOption>

        init(viewModel: ContentViewModel) {
            selectedOutputFormat = viewModel.binding(to: \.selectedOutputFormat)
            selectedVideoEncoder = viewModel.binding(to: \.selectedVideoEncoder)
            selectedResolution = viewModel.binding(to: \.selectedResolution)
            selectedFrameRate = viewModel.binding(to: \.selectedFrameRate)
            selectedGIFPlaybackSpeed = viewModel.binding(to: \.selectedGIFPlaybackSpeed)
            selectedVideoBitRate = viewModel.binding(to: \.selectedVideoBitRate)
            customVideoBitRate = viewModel.binding(to: \.customVideoBitRate)
            selectedAudioEncoder = viewModel.binding(to: \.selectedAudioEncoder)
            selectedAudioMode = viewModel.binding(to: \.selectedAudioMode)
            selectedSampleRate = viewModel.binding(to: \.selectedSampleRate)
            selectedAudioBitRate = viewModel.binding(to: \.selectedAudioBitRate)
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

    struct ImageFormBindings {
        let selectedOutputFormat: Binding<ImageFormatOption>
        let selectedResolution: Binding<ResolutionOption>
        let selectedQuality: Binding<ImageQualityOption>
        let selectedPNGCompressionLevel: Binding<PNGCompressionLevelOption>
        let preserveAnimation: Binding<Bool>

        init(viewModel: ContentViewModel) {
            selectedOutputFormat = viewModel.binding(to: \.selectedImageOutputFormat)
            selectedResolution = viewModel.binding(to: \.selectedImageResolution)
            selectedQuality = viewModel.binding(to: \.selectedImageQuality)
            selectedPNGCompressionLevel = viewModel.binding(to: \.selectedPNGCompressionLevel)
            preserveAnimation = viewModel.binding(to: \.preserveImageAnimation)
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

    struct AudioFormBindings {
        let selectedOutputFormat: Binding<AudioFormatOption>
        let selectedOutputEncoder: Binding<AudioEncoderOption>
        let selectedOutputMode: Binding<AudioModeOption>
        let selectedOutputSampleRate: Binding<SampleRateOption>
        let selectedOutputBitRate: Binding<AudioBitRateOption>

        init(viewModel: ContentViewModel) {
            selectedOutputFormat = viewModel.binding(to: \.selectedAudioOutputFormat)
            selectedOutputEncoder = viewModel.binding(to: \.selectedAudioOutputEncoder)
            selectedOutputMode = viewModel.binding(to: \.selectedAudioOutputMode)
            selectedOutputSampleRate = viewModel.binding(to: \.selectedAudioOutputSampleRate)
            selectedOutputBitRate = viewModel.binding(to: \.selectedAudioOutputBitRate)
        }
    }

    private func binding<Value>(
        get: @escaping @MainActor @Sendable () -> Value,
        set: @escaping @MainActor @Sendable (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: get, set: set)
    }

    private func binding<Value>(
        to keyPath: ReferenceWritableKeyPath<ContentViewModel, Value>
    ) -> Binding<Value> {
        binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    func videoFormPresentationState() -> VideoFormPresentationState {
        VideoFormPresentationState(viewModel: self)
    }

    func videoFormBindings() -> VideoFormBindings {
        VideoFormBindings(viewModel: self)
    }

    func imageFormPresentationState() -> ImageFormPresentationState {
        ImageFormPresentationState(viewModel: self)
    }

    func imageFormBindings() -> ImageFormBindings {
        ImageFormBindings(viewModel: self)
    }

    func audioFormPresentationState() -> AudioFormPresentationState {
        AudioFormPresentationState(viewModel: self)
    }

    func audioFormBindings() -> AudioFormBindings {
        AudioFormBindings(viewModel: self)
    }
}
