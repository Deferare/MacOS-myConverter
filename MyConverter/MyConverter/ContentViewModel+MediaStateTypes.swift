import Foundation

protocol MediaRuntimeStateContainer {
    associatedtype Format: Equatable
    var media: ContentViewModel.MediaRuntimeState<Format> { get set }
}

extension ContentViewModel {
    struct MediaRuntimeState<Format: Equatable>: Equatable {
        var sourceURL: URL?
        var queuedSourceURLs: [URL] = []
        var convertedURL: URL?
        var convertedURLs: [URL] = []
        var convertedOutputURLsBySourceID: [String: URL] = [:]
        var processedSourceIDs: Set<String> = []
        var conversionErrorMessage: String?
        var sourceCompatibilityErrorMessage: String?
        var sourceCompatibilityWarningMessage: String?
        var isAnalyzingSource = false
        var isConverting = false
        var conversionProgress: Double = 0
        var currentBatchIndex = 0
        var totalBatchCount = 0
        var availableOutputFormats: [Format]

        init(availableOutputFormats: [Format]) {
            self.availableOutputFormats = availableOutputFormats
        }
    }

    struct VideoRuntimeState: Equatable {
        var media = MediaRuntimeState(
            availableOutputFormats: ContentViewModelSupport.placeholderVideoFormats()
        )
        var availableVideoEncoders: [VideoEncoderOption] = ContentViewModelSupport.placeholderVideoEncoders(
            for: ContentViewModelSupport.defaultVideoFormat()
        )
        var availableAudioEncoders: [AudioEncoderOption] = ContentViewModelSupport.placeholderVideoAudioEncoders(
            for: ContentViewModelSupport.defaultVideoFormat()
        )
    }

    struct ImageRuntimeState: Equatable {
        var media = MediaRuntimeState(
            availableOutputFormats: ContentViewModelSupport.placeholderImageFormats()
        )
        var sourceFrameCount = 0
        var sourceHasAlpha = false
    }

    struct AudioRuntimeState: Equatable {
        var media = MediaRuntimeState(
            availableOutputFormats: ContentViewModelSupport.placeholderAudioFormats()
        )
        var availableOutputEncoders: [AudioEncoderOption] = ContentViewModelSupport.placeholderAudioOutputEncoders(
            for: ContentViewModelSupport.defaultAudioFormat()
        )
    }

    struct VideoOptionsState: Equatable {
        var selectedOutputFormat: VideoFormatOption = ContentViewModelSupport.defaultVideoFormat()
        var selectedVideoEncoder: VideoEncoderOption = .h264GPU
        var selectedResolution: ResolutionOption = .original
        var selectedFrameRate: FrameRateOption = .original
        var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption = .x1_5
        var selectedVideoBitRate: VideoBitRateOption = .auto
        var customVideoBitRate = "5000"
        var selectedAudioEncoder: AudioEncoderOption = .aac
        var selectedAudioMode: AudioModeOption = .auto
        var selectedSampleRate: SampleRateOption = .hz48000
        var selectedAudioBitRate: AudioBitRateOption = .auto
    }

    struct ImageOptionsState: Equatable {
        var selectedOutputFormat = ImageFormatOption.fromImageIOTypeIdentifier("public.png")
        var selectedResolution: ResolutionOption = .original
        var selectedQuality: ImageQualityOption = .high
        var selectedPNGCompressionLevel: PNGCompressionLevelOption = .balanced
        var preserveAnimation = true
    }

    struct AudioOptionsState: Equatable {
        var selectedOutputFormat: AudioFormatOption = ContentViewModelSupport.defaultAudioFormat()
        var selectedOutputEncoder: AudioEncoderOption = .aac
        var selectedOutputMode: AudioModeOption = .auto
        var selectedOutputSampleRate: SampleRateOption = .hz48000
        var selectedOutputBitRate: AudioBitRateOption = .auto
    }
}

extension ContentViewModel.VideoRuntimeState: MediaRuntimeStateContainer {}
extension ContentViewModel.ImageRuntimeState: MediaRuntimeStateContainer {}
extension ContentViewModel.AudioRuntimeState: MediaRuntimeStateContainer {}
