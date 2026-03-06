import Combine
import Foundation

enum ConverterTab: String, CaseIterable, Identifiable {
    case video
    case audio
    case image
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video:
            return "Video"
        case .image:
            return "Image"
        case .audio:
            return "Audio"
        case .about:
            return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .video:
            return "film"
        case .image:
            return "photo"
        case .audio:
            return "waveform"
        case .about:
            return "info.circle"
        }
    }
}

@MainActor
final class ContentViewModel: ObservableObject {
    enum ConversionStatusLevel {
        case normal
        case warning
        case error
    }

    private static var defaultVideoFormat: VideoFormatOption {
        ContentViewModelSupport.defaultVideoFormat()
    }

    private static var defaultAudioFormat: AudioFormatOption {
        ContentViewModelSupport.defaultAudioFormat()
    }

    // Video state
    @Published var sourceURL: URL?
    @Published var queuedSourceURLs: [URL] = []
    @Published var convertedURL: URL?
    @Published var convertedURLs: [URL] = []
    @Published var conversionErrorMessage: String?
    @Published var sourceCompatibilityErrorMessage: String?
    @Published var sourceCompatibilityWarningMessage: String?
    @Published var isAnalyzingSource = false
    @Published var isConverting = false
    @Published var conversionProgress: Double = 0
    @Published var currentVideoBatchIndex = 0
    @Published var totalVideoBatchCount = 0
    @Published var availableOutputFormats: [VideoFormatOption] = ContentViewModelSupport.placeholderVideoFormats()
    @Published var availableVideoEncoders: [VideoEncoderOption] = ContentViewModelSupport.placeholderVideoEncoders(
        for: ContentViewModel.defaultVideoFormat
    )
    @Published var availableAudioEncoders: [AudioEncoderOption] = ContentViewModelSupport.placeholderVideoAudioEncoders(
        for: ContentViewModel.defaultVideoFormat
    )

    // Image state
    @Published var imageSourceURL: URL?
    @Published var queuedImageSourceURLs: [URL] = []
    @Published var convertedImageURL: URL?
    @Published var convertedImageURLs: [URL] = []
    @Published var imageConversionErrorMessage: String?
    @Published var imageSourceCompatibilityErrorMessage: String?
    @Published var imageSourceCompatibilityWarningMessage: String?
    @Published var isAnalyzingImageSource = false
    @Published var imageSourceFrameCount = 0
    @Published var imageSourceHasAlpha = false
    @Published var isImageConverting = false
    @Published var imageConversionProgress: Double = 0
    @Published var currentImageBatchIndex = 0
    @Published var totalImageBatchCount = 0
    @Published var availableImageOutputFormats: [ImageFormatOption] = ContentViewModelSupport.placeholderImageFormats()

    // Audio state
    @Published var audioSourceURL: URL?
    @Published var queuedAudioSourceURLs: [URL] = []
    @Published var convertedAudioURL: URL?
    @Published var convertedAudioURLs: [URL] = []
    @Published var audioConversionErrorMessage: String?
    @Published var audioSourceCompatibilityErrorMessage: String?
    @Published var audioSourceCompatibilityWarningMessage: String?
    @Published var isAnalyzingAudioSource = false
    @Published var isAudioConverting = false
    @Published var audioConversionProgress: Double = 0
    @Published var currentAudioBatchIndex = 0
    @Published var totalAudioBatchCount = 0
    @Published var availableAudioOutputFormats: [AudioFormatOption] = ContentViewModelSupport.placeholderAudioFormats()
    @Published var availableAudioOutputEncoders: [AudioEncoderOption] = ContentViewModelSupport.placeholderAudioOutputEncoders(
        for: ContentViewModel.defaultAudioFormat
    )

    @Published var isImporting = false

    // Video options
    @Published var selectedOutputFormat: VideoFormatOption = ContentViewModel.defaultVideoFormat {
        didSet {
            scheduleVideoFormatChangeHandling()
        }
    }
    @Published var selectedVideoEncoder: VideoEncoderOption = .h264GPU {
        didSet {
            scheduleVideoOptionNormalizationAndPersist()
        }
    }
    @Published var selectedResolution: ResolutionOption = .original {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedFrameRate: FrameRateOption = .original {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption = .x1_5 {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedVideoBitRate: VideoBitRateOption = .auto {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var customVideoBitRate = "5000" {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedAudioEncoder: AudioEncoderOption = .aac {
        didSet {
            scheduleVideoOptionNormalizationAndPersist()
        }
    }
    @Published var selectedAudioMode: AudioModeOption = .auto {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedSampleRate: SampleRateOption = .hz48000 {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedAudioBitRate: AudioBitRateOption = .auto {
        didSet { persistCurrentSettingsIfNeeded() }
    }

    // Image options
    @Published var selectedImageOutputFormat: ImageFormatOption = ImageFormatOption.fromImageIOTypeIdentifier("public.png") {
        didSet { persistCurrentImageSettingsIfNeeded() }
    }
    @Published var selectedImageResolution: ResolutionOption = .original {
        didSet { persistCurrentImageSettingsIfNeeded() }
    }
    @Published var selectedImageQuality: ImageQualityOption = .high {
        didSet { persistCurrentImageSettingsIfNeeded() }
    }
    @Published var selectedPNGCompressionLevel: PNGCompressionLevelOption = .balanced {
        didSet { persistCurrentImageSettingsIfNeeded() }
    }
    @Published var preserveImageAnimation = true {
        didSet { persistCurrentImageSettingsIfNeeded() }
    }

    // Audio options
    @Published var selectedAudioOutputFormat: AudioFormatOption = ContentViewModel.defaultAudioFormat {
        didSet {
            scheduleAudioFormatChangeHandling()
        }
    }
    @Published var selectedAudioOutputEncoder: AudioEncoderOption = .aac {
        didSet {
            scheduleAudioOptionNormalizationAndPersist()
        }
    }
    @Published var selectedAudioOutputMode: AudioModeOption = .auto {
        didSet { persistCurrentAudioSettingsIfNeeded() }
    }
    @Published var selectedAudioOutputSampleRate: SampleRateOption = .hz48000 {
        didSet { persistCurrentAudioSettingsIfNeeded() }
    }
    @Published var selectedAudioOutputBitRate: AudioBitRateOption = .auto {
        didSet { persistCurrentAudioSettingsIfNeeded() }
    }

    var videoSettingsBySourceID: [String: VideoConversionSettings] = [:]
    var imageSettingsBySourceID: [String: ImageConversionSettings] = [:]
    var audioSettingsBySourceID: [String: AudioConversionSettings] = [:]

    var isApplyingStoredSettings = false
    var isApplyingStoredImageSettings = false
    var isApplyingStoredAudioSettings = false

    var sourceAnalysisTask: Task<Void, Never>?
    var conversionTask: Task<Void, Never>?
    var imageSourceAnalysisTask: Task<Void, Never>?
    var imageConversionTask: Task<Void, Never>?
    var audioSourceAnalysisTask: Task<Void, Never>?
    var audioConversionTask: Task<Void, Never>?
    var pendingVideoFormatChangeTask: Task<Void, Never>?
    var pendingVideoOptionNormalizationTask: Task<Void, Never>?
    var pendingAudioFormatChangeTask: Task<Void, Never>?
    var pendingAudioOptionNormalizationTask: Task<Void, Never>?
    var pendingVideoSettingsSaveTask: Task<Void, Never>?
    var pendingImageSettingsSaveTask: Task<Void, Never>?
    var pendingAudioSettingsSaveTask: Task<Void, Never>?
    var capabilityBootstrapTask: Task<Void, Never>?

    let videoSettingsStorageKey = "ContentViewModel.VideoSettingsBySource"
    let imageSettingsStorageKey = "ContentViewModel.ImageSettingsBySource"
    let audioSettingsStorageKey = "ContentViewModel.AudioSettingsBySource"

    init() {
        videoSettingsBySourceID = loadPersistedSettings()
        imageSettingsBySourceID = loadPersistedImageSettings()
        audioSettingsBySourceID = loadPersistedAudioSettings()
        applyPlaceholderCapabilityState()
        scheduleCapabilityBootstrap()
    }
}
