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

    struct PersistedSettingsState {
        var videoSettingsBySourceID: [String: VideoConversionSettings] = [:]
        var imageSettingsBySourceID: [String: ImageConversionSettings] = [:]
        var audioSettingsBySourceID: [String: AudioConversionSettings] = [:]
        var isApplyingVideoSettings = false
        var isApplyingImageSettings = false
        var isApplyingAudioSettings = false
        let videoStorageKey = "ContentViewModel.VideoSettingsBySource"
        let imageStorageKey = "ContentViewModel.ImageSettingsBySource"
        let audioStorageKey = "ContentViewModel.AudioSettingsBySource"
    }

    struct TaskState {
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
    }

    struct VideoRuntimeState {
        var sourceURL: URL?
        var queuedSourceURLs: [URL] = []
        var convertedURL: URL?
        var convertedURLs: [URL] = []
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
            for: ContentViewModel.defaultVideoFormat
        )
        var availableAudioEncoders: [AudioEncoderOption] = ContentViewModelSupport.placeholderVideoAudioEncoders(
            for: ContentViewModel.defaultVideoFormat
        )
    }

    struct ImageRuntimeState {
        var sourceURL: URL?
        var queuedSourceURLs: [URL] = []
        var convertedURL: URL?
        var convertedURLs: [URL] = []
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
            for: ContentViewModel.defaultAudioFormat
        )
    }

    struct VideoOptionsState {
        var selectedOutputFormat: VideoFormatOption = ContentViewModel.defaultVideoFormat
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
        var selectedOutputFormat: AudioFormatOption = ContentViewModel.defaultAudioFormat
        var selectedOutputEncoder: AudioEncoderOption = .aac
        var selectedOutputMode: AudioModeOption = .auto
        var selectedOutputSampleRate: SampleRateOption = .hz48000
        var selectedOutputBitRate: AudioBitRateOption = .auto
    }

    private static var defaultVideoFormat: VideoFormatOption {
        ContentViewModelSupport.defaultVideoFormat()
    }

    private static var defaultAudioFormat: AudioFormatOption {
        ContentViewModelSupport.defaultAudioFormat()
    }

    @Published private var videoRuntimeState = VideoRuntimeState()
    @Published private var imageRuntimeState = ImageRuntimeState()
    @Published private var audioRuntimeState = AudioRuntimeState()
    @Published private var videoOptionsState = VideoOptionsState()
    @Published private var imageOptionsState = ImageOptionsState()
    @Published private var audioOptionsState = AudioOptionsState()

    @Published var isImporting = false

    var settingsState = PersistedSettingsState()
    var taskState = TaskState()

    init() {
        settingsState.videoSettingsBySourceID = loadPersistedSourceSettings(using: videoSettingsDescriptor())
        settingsState.imageSettingsBySourceID = loadPersistedSourceSettings(using: imageSettingsDescriptor())
        settingsState.audioSettingsBySourceID = loadPersistedSourceSettings(using: audioSettingsDescriptor())
        applyPlaceholderCapabilityState()
        scheduleCapabilityBootstrap()
    }
}

extension ContentViewModel {
    // Video state
    var sourceURL: URL? {
        get { videoRuntimeState.sourceURL }
        set { videoRuntimeState.sourceURL = newValue }
    }

    var queuedSourceURLs: [URL] {
        get { videoRuntimeState.queuedSourceURLs }
        set { videoRuntimeState.queuedSourceURLs = newValue }
    }

    var convertedURL: URL? {
        get { videoRuntimeState.convertedURL }
        set { videoRuntimeState.convertedURL = newValue }
    }

    var convertedURLs: [URL] {
        get { videoRuntimeState.convertedURLs }
        set { videoRuntimeState.convertedURLs = newValue }
    }

    var conversionErrorMessage: String? {
        get { videoRuntimeState.conversionErrorMessage }
        set { videoRuntimeState.conversionErrorMessage = newValue }
    }

    var sourceCompatibilityErrorMessage: String? {
        get { videoRuntimeState.sourceCompatibilityErrorMessage }
        set { videoRuntimeState.sourceCompatibilityErrorMessage = newValue }
    }

    var sourceCompatibilityWarningMessage: String? {
        get { videoRuntimeState.sourceCompatibilityWarningMessage }
        set { videoRuntimeState.sourceCompatibilityWarningMessage = newValue }
    }

    var isAnalyzingSource: Bool {
        get { videoRuntimeState.isAnalyzingSource }
        set { videoRuntimeState.isAnalyzingSource = newValue }
    }

    var isConverting: Bool {
        get { videoRuntimeState.isConverting }
        set { videoRuntimeState.isConverting = newValue }
    }

    var conversionProgress: Double {
        get { videoRuntimeState.conversionProgress }
        set { videoRuntimeState.conversionProgress = newValue }
    }

    var currentVideoBatchIndex: Int {
        get { videoRuntimeState.currentBatchIndex }
        set { videoRuntimeState.currentBatchIndex = newValue }
    }

    var totalVideoBatchCount: Int {
        get { videoRuntimeState.totalBatchCount }
        set { videoRuntimeState.totalBatchCount = newValue }
    }

    var availableOutputFormats: [VideoFormatOption] {
        get { videoRuntimeState.availableOutputFormats }
        set { videoRuntimeState.availableOutputFormats = newValue }
    }

    var availableVideoEncoders: [VideoEncoderOption] {
        get { videoRuntimeState.availableVideoEncoders }
        set { videoRuntimeState.availableVideoEncoders = newValue }
    }

    var availableAudioEncoders: [AudioEncoderOption] {
        get { videoRuntimeState.availableAudioEncoders }
        set { videoRuntimeState.availableAudioEncoders = newValue }
    }

    // Image state
    var imageSourceURL: URL? {
        get { imageRuntimeState.sourceURL }
        set { imageRuntimeState.sourceURL = newValue }
    }

    var queuedImageSourceURLs: [URL] {
        get { imageRuntimeState.queuedSourceURLs }
        set { imageRuntimeState.queuedSourceURLs = newValue }
    }

    var convertedImageURL: URL? {
        get { imageRuntimeState.convertedURL }
        set { imageRuntimeState.convertedURL = newValue }
    }

    var convertedImageURLs: [URL] {
        get { imageRuntimeState.convertedURLs }
        set { imageRuntimeState.convertedURLs = newValue }
    }

    var imageConversionErrorMessage: String? {
        get { imageRuntimeState.conversionErrorMessage }
        set { imageRuntimeState.conversionErrorMessage = newValue }
    }

    var imageSourceCompatibilityErrorMessage: String? {
        get { imageRuntimeState.sourceCompatibilityErrorMessage }
        set { imageRuntimeState.sourceCompatibilityErrorMessage = newValue }
    }

    var imageSourceCompatibilityWarningMessage: String? {
        get { imageRuntimeState.sourceCompatibilityWarningMessage }
        set { imageRuntimeState.sourceCompatibilityWarningMessage = newValue }
    }

    var isAnalyzingImageSource: Bool {
        get { imageRuntimeState.isAnalyzingSource }
        set { imageRuntimeState.isAnalyzingSource = newValue }
    }

    var imageSourceFrameCount: Int {
        get { imageRuntimeState.sourceFrameCount }
        set { imageRuntimeState.sourceFrameCount = newValue }
    }

    var imageSourceHasAlpha: Bool {
        get { imageRuntimeState.sourceHasAlpha }
        set { imageRuntimeState.sourceHasAlpha = newValue }
    }

    var isImageConverting: Bool {
        get { imageRuntimeState.isConverting }
        set { imageRuntimeState.isConverting = newValue }
    }

    var imageConversionProgress: Double {
        get { imageRuntimeState.conversionProgress }
        set { imageRuntimeState.conversionProgress = newValue }
    }

    var currentImageBatchIndex: Int {
        get { imageRuntimeState.currentBatchIndex }
        set { imageRuntimeState.currentBatchIndex = newValue }
    }

    var totalImageBatchCount: Int {
        get { imageRuntimeState.totalBatchCount }
        set { imageRuntimeState.totalBatchCount = newValue }
    }

    var availableImageOutputFormats: [ImageFormatOption] {
        get { imageRuntimeState.availableOutputFormats }
        set { imageRuntimeState.availableOutputFormats = newValue }
    }

    // Audio state
    var audioSourceURL: URL? {
        get { audioRuntimeState.sourceURL }
        set { audioRuntimeState.sourceURL = newValue }
    }

    var queuedAudioSourceURLs: [URL] {
        get { audioRuntimeState.queuedSourceURLs }
        set { audioRuntimeState.queuedSourceURLs = newValue }
    }

    var convertedAudioURL: URL? {
        get { audioRuntimeState.convertedURL }
        set { audioRuntimeState.convertedURL = newValue }
    }

    var convertedAudioURLs: [URL] {
        get { audioRuntimeState.convertedURLs }
        set { audioRuntimeState.convertedURLs = newValue }
    }

    var audioConversionErrorMessage: String? {
        get { audioRuntimeState.conversionErrorMessage }
        set { audioRuntimeState.conversionErrorMessage = newValue }
    }

    var audioSourceCompatibilityErrorMessage: String? {
        get { audioRuntimeState.sourceCompatibilityErrorMessage }
        set { audioRuntimeState.sourceCompatibilityErrorMessage = newValue }
    }

    var audioSourceCompatibilityWarningMessage: String? {
        get { audioRuntimeState.sourceCompatibilityWarningMessage }
        set { audioRuntimeState.sourceCompatibilityWarningMessage = newValue }
    }

    var isAnalyzingAudioSource: Bool {
        get { audioRuntimeState.isAnalyzingSource }
        set { audioRuntimeState.isAnalyzingSource = newValue }
    }

    var isAudioConverting: Bool {
        get { audioRuntimeState.isConverting }
        set { audioRuntimeState.isConverting = newValue }
    }

    var audioConversionProgress: Double {
        get { audioRuntimeState.conversionProgress }
        set { audioRuntimeState.conversionProgress = newValue }
    }

    var currentAudioBatchIndex: Int {
        get { audioRuntimeState.currentBatchIndex }
        set { audioRuntimeState.currentBatchIndex = newValue }
    }

    var totalAudioBatchCount: Int {
        get { audioRuntimeState.totalBatchCount }
        set { audioRuntimeState.totalBatchCount = newValue }
    }

    var availableAudioOutputFormats: [AudioFormatOption] {
        get { audioRuntimeState.availableOutputFormats }
        set { audioRuntimeState.availableOutputFormats = newValue }
    }

    var availableAudioOutputEncoders: [AudioEncoderOption] {
        get { audioRuntimeState.availableOutputEncoders }
        set { audioRuntimeState.availableOutputEncoders = newValue }
    }

    // Video options
    var selectedOutputFormat: VideoFormatOption {
        get { videoOptionsState.selectedOutputFormat }
        set {
            videoOptionsState.selectedOutputFormat = newValue
            scheduleVideoFormatChangeHandling()
        }
    }

    var selectedVideoEncoder: VideoEncoderOption {
        get { videoOptionsState.selectedVideoEncoder }
        set {
            videoOptionsState.selectedVideoEncoder = newValue
            scheduleVideoOptionNormalizationAndPersist()
        }
    }

    var selectedResolution: ResolutionOption {
        get { videoOptionsState.selectedResolution }
        set {
            videoOptionsState.selectedResolution = newValue
            persistCurrentSettingsIfNeeded()
        }
    }

    var selectedFrameRate: FrameRateOption {
        get { videoOptionsState.selectedFrameRate }
        set {
            videoOptionsState.selectedFrameRate = newValue
            persistCurrentSettingsIfNeeded()
        }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { videoOptionsState.selectedGIFPlaybackSpeed }
        set {
            videoOptionsState.selectedGIFPlaybackSpeed = newValue
            persistCurrentSettingsIfNeeded()
        }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { videoOptionsState.selectedVideoBitRate }
        set {
            videoOptionsState.selectedVideoBitRate = newValue
            persistCurrentSettingsIfNeeded()
        }
    }

    var customVideoBitRate: String {
        get { videoOptionsState.customVideoBitRate }
        set {
            videoOptionsState.customVideoBitRate = newValue
            persistCurrentSettingsIfNeeded()
        }
    }

    var selectedAudioEncoder: AudioEncoderOption {
        get { videoOptionsState.selectedAudioEncoder }
        set {
            videoOptionsState.selectedAudioEncoder = newValue
            scheduleVideoOptionNormalizationAndPersist()
        }
    }

    var selectedAudioMode: AudioModeOption {
        get { videoOptionsState.selectedAudioMode }
        set {
            videoOptionsState.selectedAudioMode = newValue
            persistCurrentSettingsIfNeeded()
        }
    }

    var selectedSampleRate: SampleRateOption {
        get { videoOptionsState.selectedSampleRate }
        set {
            videoOptionsState.selectedSampleRate = newValue
            persistCurrentSettingsIfNeeded()
        }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { videoOptionsState.selectedAudioBitRate }
        set {
            videoOptionsState.selectedAudioBitRate = newValue
            persistCurrentSettingsIfNeeded()
        }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { imageOptionsState.selectedOutputFormat }
        set {
            imageOptionsState.selectedOutputFormat = newValue
            persistCurrentImageSettingsIfNeeded()
        }
    }

    var selectedImageResolution: ResolutionOption {
        get { imageOptionsState.selectedResolution }
        set {
            imageOptionsState.selectedResolution = newValue
            persistCurrentImageSettingsIfNeeded()
        }
    }

    var selectedImageQuality: ImageQualityOption {
        get { imageOptionsState.selectedQuality }
        set {
            imageOptionsState.selectedQuality = newValue
            persistCurrentImageSettingsIfNeeded()
        }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { imageOptionsState.selectedPNGCompressionLevel }
        set {
            imageOptionsState.selectedPNGCompressionLevel = newValue
            persistCurrentImageSettingsIfNeeded()
        }
    }

    var preserveImageAnimation: Bool {
        get { imageOptionsState.preserveAnimation }
        set {
            imageOptionsState.preserveAnimation = newValue
            persistCurrentImageSettingsIfNeeded()
        }
    }

    // Audio options
    var selectedAudioOutputFormat: AudioFormatOption {
        get { audioOptionsState.selectedOutputFormat }
        set {
            audioOptionsState.selectedOutputFormat = newValue
            scheduleAudioFormatChangeHandling()
        }
    }

    var selectedAudioOutputEncoder: AudioEncoderOption {
        get { audioOptionsState.selectedOutputEncoder }
        set {
            audioOptionsState.selectedOutputEncoder = newValue
            scheduleAudioOptionNormalizationAndPersist()
        }
    }

    var selectedAudioOutputMode: AudioModeOption {
        get { audioOptionsState.selectedOutputMode }
        set {
            audioOptionsState.selectedOutputMode = newValue
            persistCurrentAudioSettingsIfNeeded()
        }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { audioOptionsState.selectedOutputSampleRate }
        set {
            audioOptionsState.selectedOutputSampleRate = newValue
            persistCurrentAudioSettingsIfNeeded()
        }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { audioOptionsState.selectedOutputBitRate }
        set {
            audioOptionsState.selectedOutputBitRate = newValue
            persistCurrentAudioSettingsIfNeeded()
        }
    }
}
