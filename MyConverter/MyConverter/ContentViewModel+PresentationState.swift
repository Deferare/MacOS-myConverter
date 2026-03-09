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
    }

    struct ImageFormBindings {
        let selectedOutputFormat: Binding<ImageFormatOption>
        let selectedResolution: Binding<ResolutionOption>
        let selectedQuality: Binding<ImageQualityOption>
        let selectedPNGCompressionLevel: Binding<PNGCompressionLevelOption>
        let preserveAnimation: Binding<Bool>
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
    }

    struct AudioFormBindings {
        let selectedOutputFormat: Binding<AudioFormatOption>
        let selectedOutputEncoder: Binding<AudioEncoderOption>
        let selectedOutputMode: Binding<AudioModeOption>
        let selectedOutputSampleRate: Binding<SampleRateOption>
        let selectedOutputBitRate: Binding<AudioBitRateOption>
    }

    private func binding<Value>(
        get: @escaping @MainActor @Sendable () -> Value,
        set: @escaping @MainActor @Sendable (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: get, set: set)
    }

    func videoFormPresentationState() -> VideoFormPresentationState {
        VideoFormPresentationState(
            isConverting: isConverting,
            selectedOutputFormat: selectedOutputFormat,
            selectedVideoEncoder: selectedVideoEncoder,
            selectedResolution: selectedResolution,
            selectedFrameRate: selectedFrameRate,
            selectedGIFPlaybackSpeed: selectedGIFPlaybackSpeed,
            selectedVideoBitRate: selectedVideoBitRate,
            customVideoBitRate: customVideoBitRate,
            selectedAudioEncoder: selectedAudioEncoder,
            selectedAudioMode: selectedAudioMode,
            selectedSampleRate: selectedSampleRate,
            selectedAudioBitRate: selectedAudioBitRate,
            outputFormatOptions: outputFormatOptions,
            videoEncoderOptions: videoEncoderOptions,
            audioEncoderOptions: audioEncoderOptions,
            shouldShowVideoEncoderOption: shouldShowVideoEncoderOption,
            shouldShowAudioSettings: shouldShowAudioSettings,
            shouldShowGIFPlaybackSpeedOption: shouldShowGIFPlaybackSpeedOption,
            shouldShowVideoBitRateOption: shouldShowVideoBitRateOption,
            shouldShowAudioSampleRateOption: shouldShowAudioSampleRateOption,
            shouldShowAudioBitRateOption: shouldShowAudioBitRateOption
        )
    }

    func videoFormBindings() -> VideoFormBindings {
        VideoFormBindings(
            selectedOutputFormat: binding(
                get: { self.selectedOutputFormat },
                set: { self.selectedOutputFormat = $0 }
            ),
            selectedVideoEncoder: binding(
                get: { self.selectedVideoEncoder },
                set: { self.selectedVideoEncoder = $0 }
            ),
            selectedResolution: binding(
                get: { self.selectedResolution },
                set: { self.selectedResolution = $0 }
            ),
            selectedFrameRate: binding(
                get: { self.selectedFrameRate },
                set: { self.selectedFrameRate = $0 }
            ),
            selectedGIFPlaybackSpeed: binding(
                get: { self.selectedGIFPlaybackSpeed },
                set: { self.selectedGIFPlaybackSpeed = $0 }
            ),
            selectedVideoBitRate: binding(
                get: { self.selectedVideoBitRate },
                set: { self.selectedVideoBitRate = $0 }
            ),
            customVideoBitRate: binding(
                get: { self.customVideoBitRate },
                set: { self.customVideoBitRate = $0 }
            ),
            selectedAudioEncoder: binding(
                get: { self.selectedAudioEncoder },
                set: { self.selectedAudioEncoder = $0 }
            ),
            selectedAudioMode: binding(
                get: { self.selectedAudioMode },
                set: { self.selectedAudioMode = $0 }
            ),
            selectedSampleRate: binding(
                get: { self.selectedSampleRate },
                set: { self.selectedSampleRate = $0 }
            ),
            selectedAudioBitRate: binding(
                get: { self.selectedAudioBitRate },
                set: { self.selectedAudioBitRate = $0 }
            )
        )
    }

    func imageFormPresentationState() -> ImageFormPresentationState {
        ImageFormPresentationState(
            isConverting: isImageConverting,
            selectedOutputFormat: selectedImageOutputFormat,
            selectedResolution: selectedImageResolution,
            selectedQuality: selectedImageQuality,
            selectedPNGCompressionLevel: selectedPNGCompressionLevel,
            preserveAnimation: preserveImageAnimation,
            outputFormatOptions: imageOutputFormatOptions,
            shouldShowImageQualityOption: shouldShowImageQualityOption,
            shouldShowPNGCompressionOption: shouldShowPNGCompressionOption,
            shouldShowPreserveAnimationOption: shouldShowPreserveAnimationOption,
            hintMessage: hintMessage(for: .image)
        )
    }

    func imageFormBindings() -> ImageFormBindings {
        ImageFormBindings(
            selectedOutputFormat: binding(
                get: { self.selectedImageOutputFormat },
                set: { self.selectedImageOutputFormat = $0 }
            ),
            selectedResolution: binding(
                get: { self.selectedImageResolution },
                set: { self.selectedImageResolution = $0 }
            ),
            selectedQuality: binding(
                get: { self.selectedImageQuality },
                set: { self.selectedImageQuality = $0 }
            ),
            selectedPNGCompressionLevel: binding(
                get: { self.selectedPNGCompressionLevel },
                set: { self.selectedPNGCompressionLevel = $0 }
            ),
            preserveAnimation: binding(
                get: { self.preserveImageAnimation },
                set: { self.preserveImageAnimation = $0 }
            )
        )
    }

    func audioFormPresentationState() -> AudioFormPresentationState {
        AudioFormPresentationState(
            isConverting: isAudioConverting,
            selectedOutputFormat: selectedAudioOutputFormat,
            selectedOutputEncoder: selectedAudioOutputEncoder,
            selectedOutputMode: selectedAudioOutputMode,
            selectedOutputSampleRate: selectedAudioOutputSampleRate,
            selectedOutputBitRate: selectedAudioOutputBitRate,
            outputFormatOptions: audioOutputFormatOptions,
            audioOutputEncoderOptions: audioOutputEncoderOptions,
            shouldShowAudioOutputSampleRateOption: shouldShowAudioOutputSampleRateOption,
            shouldShowAudioOutputBitRateOption: shouldShowAudioOutputBitRateOption,
            hintMessage: hintMessage(for: .audio)
        )
    }

    func audioFormBindings() -> AudioFormBindings {
        AudioFormBindings(
            selectedOutputFormat: binding(
                get: { self.selectedAudioOutputFormat },
                set: { self.selectedAudioOutputFormat = $0 }
            ),
            selectedOutputEncoder: binding(
                get: { self.selectedAudioOutputEncoder },
                set: { self.selectedAudioOutputEncoder = $0 }
            ),
            selectedOutputMode: binding(
                get: { self.selectedAudioOutputMode },
                set: { self.selectedAudioOutputMode = $0 }
            ),
            selectedOutputSampleRate: binding(
                get: { self.selectedAudioOutputSampleRate },
                set: { self.selectedAudioOutputSampleRate = $0 }
            ),
            selectedOutputBitRate: binding(
                get: { self.selectedAudioOutputBitRate },
                set: { self.selectedAudioOutputBitRate = $0 }
            )
        )
    }
}
