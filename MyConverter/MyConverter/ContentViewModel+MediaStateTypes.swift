import Foundation

extension ContentViewModel {
    struct VideoRuntimeState {
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
        var availableOutputFormats: [VideoFormatOption] = ContentViewModelSupport.placeholderVideoFormats()
        var availableVideoEncoders: [VideoEncoderOption] = ContentViewModelSupport.placeholderVideoEncoders(
            for: ContentViewModelSupport.defaultVideoFormat()
        )
        var availableAudioEncoders: [AudioEncoderOption] = ContentViewModelSupport.placeholderVideoAudioEncoders(
            for: ContentViewModelSupport.defaultVideoFormat()
        )
    }

    struct ImageRuntimeState {
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
        var sourceFrameCount = 0
        var sourceHasAlpha = false
        var isConverting = false
        var conversionProgress: Double = 0
        var currentBatchIndex = 0
        var totalBatchCount = 0
        var availableOutputFormats: [ImageFormatOption] = ContentViewModelSupport.placeholderImageFormats()
    }

    struct AudioRuntimeState {
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
        var availableOutputFormats: [AudioFormatOption] = ContentViewModelSupport.placeholderAudioFormats()
        var availableOutputEncoders: [AudioEncoderOption] = ContentViewModelSupport.placeholderAudioOutputEncoders(
            for: ContentViewModelSupport.defaultAudioFormat()
        )
    }

    struct VideoOptionsState {
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

    struct ImageOptionsState {
        var selectedOutputFormat = ImageFormatOption.fromImageIOTypeIdentifier("public.png")
        var selectedResolution: ResolutionOption = .original
        var selectedQuality: ImageQualityOption = .high
        var selectedPNGCompressionLevel: PNGCompressionLevelOption = .balanced
        var preserveAnimation = true
    }

    struct AudioOptionsState {
        var selectedOutputFormat: AudioFormatOption = ContentViewModelSupport.defaultAudioFormat()
        var selectedOutputEncoder: AudioEncoderOption = .aac
        var selectedOutputMode: AudioModeOption = .auto
        var selectedOutputSampleRate: SampleRateOption = .hz48000
        var selectedOutputBitRate: AudioBitRateOption = .auto
    }
}
