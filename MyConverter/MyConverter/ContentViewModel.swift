import Combine
import Foundation
import UniformTypeIdentifiers

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
        if let preferred = VideoFormatOption.defaultSelection(from: VideoConversionEngine.defaultOutputFormats()) {
            return preferred
        }
        return VideoFormatOption.fromFFmpegExtension("mp4", muxer: "mp4")
    }

    private static var defaultAudioFormat: AudioFormatOption {
        if let preferred = AudioFormatOption.defaultSelection(from: VideoConversionEngine.defaultAudioOutputFormats()) {
            return preferred
        }
        return AudioFormatOption.fromFFmpegExtension("m4a", muxer: "ipod")
    }

    // Video state
    @Published private(set) var sourceURL: URL?
    @Published private(set) var queuedSourceURLs: [URL] = []
    @Published private(set) var convertedURL: URL?
    @Published private(set) var convertedURLs: [URL] = []
    @Published private(set) var conversionErrorMessage: String?
    @Published private(set) var sourceCompatibilityErrorMessage: String?
    @Published private(set) var sourceCompatibilityWarningMessage: String?
    @Published private(set) var isAnalyzingSource = false
    @Published var isConverting = false
    @Published private(set) var conversionProgress: Double = 0
    @Published private(set) var currentVideoBatchIndex = 0
    @Published private(set) var totalVideoBatchCount = 0
    @Published private(set) var availableOutputFormats: [VideoFormatOption] = VideoConversionEngine.defaultOutputFormats()
    @Published private(set) var availableVideoEncoders: [VideoEncoderOption] = [.auto]
    @Published private(set) var availableAudioEncoders: [AudioEncoderOption] = [.auto]

    // Image state
    @Published private(set) var imageSourceURL: URL?
    @Published private(set) var queuedImageSourceURLs: [URL] = []
    @Published private(set) var convertedImageURL: URL?
    @Published private(set) var convertedImageURLs: [URL] = []
    @Published private(set) var imageConversionErrorMessage: String?
    @Published private(set) var imageSourceCompatibilityErrorMessage: String?
    @Published private(set) var imageSourceCompatibilityWarningMessage: String?
    @Published private(set) var isAnalyzingImageSource = false
    @Published private(set) var imageSourceFrameCount = 0
    @Published private(set) var imageSourceHasAlpha = false
    @Published var isImageConverting = false
    @Published private(set) var imageConversionProgress: Double = 0
    @Published private(set) var currentImageBatchIndex = 0
    @Published private(set) var totalImageBatchCount = 0
    @Published private(set) var availableImageOutputFormats: [ImageFormatOption] = ImageConversionEngine.defaultOutputFormats()

    // Audio state
    @Published private(set) var audioSourceURL: URL?
    @Published private(set) var queuedAudioSourceURLs: [URL] = []
    @Published private(set) var convertedAudioURL: URL?
    @Published private(set) var convertedAudioURLs: [URL] = []
    @Published private(set) var audioConversionErrorMessage: String?
    @Published private(set) var audioSourceCompatibilityErrorMessage: String?
    @Published private(set) var audioSourceCompatibilityWarningMessage: String?
    @Published private(set) var isAnalyzingAudioSource = false
    @Published var isAudioConverting = false
    @Published private(set) var audioConversionProgress: Double = 0
    @Published private(set) var currentAudioBatchIndex = 0
    @Published private(set) var totalAudioBatchCount = 0
    @Published private(set) var availableAudioOutputFormats: [AudioFormatOption] = VideoConversionEngine.defaultAudioOutputFormats()
    @Published private(set) var availableAudioOutputEncoders: [AudioEncoderOption] = [.auto]

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

    private struct VideoConversionSettings {
        var outputFormatID: String = ContentViewModel.defaultVideoFormat.id
        var videoEncoder: VideoEncoderOption = .h264GPU
        var resolution: ResolutionOption = .original
        var frameRate: FrameRateOption = .original
        var gifPlaybackSpeed: GIFPlaybackSpeedOption = .x1_5
        var videoBitRate: VideoBitRateOption = .auto
        var customVideoBitRate: String = "5000"
        var audioEncoder: AudioEncoderOption = .aac
        var audioMode: AudioModeOption = .auto
        var sampleRate: SampleRateOption = .hz48000
        var audioBitRate: AudioBitRateOption = .auto
    }

    private struct PersistedVideoConversionSettings: Codable {
        var outputFormat: String
        var videoEncoder: String
        var resolution: String
        var frameRate: String
        var gifPlaybackSpeed: String
        var videoBitRate: String
        var customVideoBitRate: String
        var audioEncoder: String
        var audioMode: String
        var sampleRate: String
        var audioBitRate: String

        private enum CodingKeys: String, CodingKey {
            case outputFormat
            case videoEncoder
            case resolution
            case frameRate
            case gifPlaybackSpeed
            case videoBitRate
            case customVideoBitRate
            case audioEncoder
            case audioMode
            case sampleRate
            case audioBitRate
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            outputFormat = try container.decode(String.self, forKey: .outputFormat)
            videoEncoder = try container.decode(String.self, forKey: .videoEncoder)
            resolution = try container.decode(String.self, forKey: .resolution)
            frameRate = try container.decode(String.self, forKey: .frameRate)
            gifPlaybackSpeed = try container.decodeIfPresent(String.self, forKey: .gifPlaybackSpeed) ?? GIFPlaybackSpeedOption.x1_5.rawValue
            videoBitRate = try container.decode(String.self, forKey: .videoBitRate)
            customVideoBitRate = try container.decode(String.self, forKey: .customVideoBitRate)
            audioEncoder = try container.decode(String.self, forKey: .audioEncoder)
            audioMode = try container.decode(String.self, forKey: .audioMode)
            sampleRate = try container.decode(String.self, forKey: .sampleRate)
            audioBitRate = try container.decode(String.self, forKey: .audioBitRate)
        }

        init(from settings: VideoConversionSettings) {
            outputFormat = settings.outputFormatID
            videoEncoder = settings.videoEncoder.rawValue
            resolution = settings.resolution.rawValue
            frameRate = settings.frameRate.rawValue
            gifPlaybackSpeed = settings.gifPlaybackSpeed.rawValue
            videoBitRate = settings.videoBitRate.rawValue
            customVideoBitRate = settings.customVideoBitRate
            audioEncoder = settings.audioEncoder.rawValue
            audioMode = settings.audioMode.rawValue
            sampleRate = settings.sampleRate.rawValue
            audioBitRate = settings.audioBitRate.rawValue
        }

        var restoredSettings: VideoConversionSettings {
            VideoConversionSettings(
                outputFormatID: outputFormat,
                videoEncoder: VideoEncoderOption(rawValue: videoEncoder) ?? .h264GPU,
                resolution: ResolutionOption(rawValue: resolution) ?? .original,
                frameRate: FrameRateOption(rawValue: frameRate) ?? .original,
                gifPlaybackSpeed: GIFPlaybackSpeedOption(rawValue: gifPlaybackSpeed) ?? .x1_5,
                videoBitRate: VideoBitRateOption(rawValue: videoBitRate) ?? .auto,
                customVideoBitRate: customVideoBitRate,
                audioEncoder: AudioEncoderOption(rawValue: audioEncoder) ?? .aac,
                audioMode: AudioModeOption(rawValue: audioMode) ?? .auto,
                sampleRate: SampleRateOption(rawValue: sampleRate) ?? .hz48000,
                audioBitRate: AudioBitRateOption(rawValue: audioBitRate) ?? .auto
            )
        }
    }

    private struct ImageConversionSettings {
        var outputFormatID: String = "public.png"
        var resolution: ResolutionOption = .original
        var quality: ImageQualityOption = .high
        var pngCompressionLevel: PNGCompressionLevelOption = .balanced
        var preserveAnimation: Bool = true
    }

    private struct PersistedImageConversionSettings: Codable {
        var outputFormat: String
        var resolution: String
        var quality: String
        var pngCompressionLevel: String
        var preserveAnimation: Bool

        private enum CodingKeys: String, CodingKey {
            case outputFormat
            case resolution
            case quality
            case pngCompressionLevel
            case preserveAnimation
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            outputFormat = try container.decode(String.self, forKey: .outputFormat)
            resolution = try container.decode(String.self, forKey: .resolution)
            quality = try container.decode(String.self, forKey: .quality)
            pngCompressionLevel = try container.decodeIfPresent(String.self, forKey: .pngCompressionLevel) ?? PNGCompressionLevelOption.balanced.rawValue
            preserveAnimation = try container.decodeIfPresent(Bool.self, forKey: .preserveAnimation) ?? true
        }

        init(from settings: ImageConversionSettings) {
            outputFormat = settings.outputFormatID
            resolution = settings.resolution.rawValue
            quality = settings.quality.rawValue
            pngCompressionLevel = settings.pngCompressionLevel.rawValue
            preserveAnimation = settings.preserveAnimation
        }

        var restoredSettings: ImageConversionSettings {
            ImageConversionSettings(
                outputFormatID: outputFormat,
                resolution: ResolutionOption(rawValue: resolution) ?? .original,
                quality: ImageQualityOption(rawValue: quality) ?? .high,
                pngCompressionLevel: PNGCompressionLevelOption(rawValue: pngCompressionLevel) ?? .balanced,
                preserveAnimation: preserveAnimation
            )
        }
    }

    private struct AudioConversionSettings {
        var outputFormatID: String = ContentViewModel.defaultAudioFormat.id
        var audioEncoder: AudioEncoderOption = .aac
        var audioMode: AudioModeOption = .auto
        var sampleRate: SampleRateOption = .hz48000
        var audioBitRate: AudioBitRateOption = .auto
    }

    private struct PersistedAudioConversionSettings: Codable {
        var outputFormat: String
        var audioEncoder: String
        var audioMode: String
        var sampleRate: String
        var audioBitRate: String

        private enum CodingKeys: String, CodingKey {
            case outputFormat
            case audioEncoder
            case audioMode
            case sampleRate
            case audioBitRate
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            outputFormat = try container.decode(String.self, forKey: .outputFormat)
            audioEncoder = try container.decode(String.self, forKey: .audioEncoder)
            audioMode = try container.decode(String.self, forKey: .audioMode)
            sampleRate = try container.decode(String.self, forKey: .sampleRate)
            audioBitRate = try container.decode(String.self, forKey: .audioBitRate)
        }

        init(from settings: AudioConversionSettings) {
            outputFormat = settings.outputFormatID
            audioEncoder = settings.audioEncoder.rawValue
            audioMode = settings.audioMode.rawValue
            sampleRate = settings.sampleRate.rawValue
            audioBitRate = settings.audioBitRate.rawValue
        }

        var restoredSettings: AudioConversionSettings {
            AudioConversionSettings(
                outputFormatID: outputFormat,
                audioEncoder: AudioEncoderOption(rawValue: audioEncoder) ?? .aac,
                audioMode: AudioModeOption(rawValue: audioMode) ?? .auto,
                sampleRate: SampleRateOption(rawValue: sampleRate) ?? .hz48000,
                audioBitRate: AudioBitRateOption(rawValue: audioBitRate) ?? .auto
            )
        }
    }

    private var videoSettingsBySourceID: [String: VideoConversionSettings] = [:]
    private var imageSettingsBySourceID: [String: ImageConversionSettings] = [:]
    private var audioSettingsBySourceID: [String: AudioConversionSettings] = [:]

    private var isApplyingStoredSettings = false
    private var isApplyingStoredImageSettings = false
    private var isApplyingStoredAudioSettings = false

    private var sourceAnalysisTask: Task<Void, Never>?
    private var conversionTask: Task<Void, Never>?
    private var imageSourceAnalysisTask: Task<Void, Never>?
    private var imageConversionTask: Task<Void, Never>?
    private var audioSourceAnalysisTask: Task<Void, Never>?
    private var audioConversionTask: Task<Void, Never>?
    private var pendingVideoFormatChangeTask: Task<Void, Never>?
    private var pendingVideoOptionNormalizationTask: Task<Void, Never>?
    private var pendingAudioFormatChangeTask: Task<Void, Never>?
    private var pendingAudioOptionNormalizationTask: Task<Void, Never>?

    private let videoSettingsStorageKey = "ContentViewModel.VideoSettingsBySource"
    private let imageSettingsStorageKey = "ContentViewModel.ImageSettingsBySource"
    private let audioSettingsStorageKey = "ContentViewModel.AudioSettingsBySource"

    init() {
        videoSettingsBySourceID = loadPersistedSettings()
        imageSettingsBySourceID = loadPersistedImageSettings()
        audioSettingsBySourceID = loadPersistedAudioSettings()
        availableOutputFormats = VideoConversionEngine.defaultOutputFormats()
        ensureSelectedVideoOutputFormatIsAvailable()
        refreshVideoCodecOptions()
        availableImageOutputFormats = ImageConversionEngine.defaultOutputFormats()
        ensureSelectedImageOutputFormatIsAvailable()
        availableAudioOutputFormats = VideoConversionEngine.defaultAudioOutputFormats()
        ensureSelectedAudioOutputFormatIsAvailable()
        refreshAudioCodecOptions()
    }

    // MARK: - Video Computed Properties

    var canConvert: Bool {
        sourceURL != nil &&
            !isConverting &&
            !isAnalyzingSource &&
            sourceCompatibilityErrorMessage == nil &&
            isVideoSettingsValid &&
            availableOutputFormats.contains(where: { $0.normalizedID == selectedOutputFormat.normalizedID })
    }

    var selectedVideoSourceURLs: [URL] {
        guard let sourceURL else { return [] }
        return [sourceURL] + queuedSourceURLs
    }

    var selectedVideoFileCount: Int {
        selectedVideoSourceURLs.count
    }

    var displayedConversionProgress: Double {
        let rawProgress = isConverting ? conversionProgress : 0
        return rawProgress < 0.01 ? 0 : rawProgress
    }

    var progressPercentageText: String {
        let percent = Int((displayedConversionProgress * 100).rounded())
        return "\(max(0, min(percent, 100)))%"
    }

    var conversionStatusMessage: String {
        conversionStatus.message
    }

    var conversionStatusLevel: ConversionStatusLevel {
        conversionStatus.level
    }

    var isVideoSettingsValid: Bool {
        if shouldShowVideoBitRateOption && selectedVideoBitRate == .custom {
            return normalizedCustomVideoBitRateKbps != nil
        }
        return true
    }

    var videoSettingsValidationMessage: String? {
        if let sourceCompatibilityErrorMessage {
            return sourceCompatibilityErrorMessage
        }
        if shouldShowVideoBitRateOption && selectedVideoBitRate == .custom && normalizedCustomVideoBitRateKbps == nil {
            return "Please enter an integer greater than 1 for Custom Bitrate (Kbps)."
        }
        if sourceURL != nil && !availableOutputFormats.contains(where: { $0.normalizedID == selectedOutputFormat.normalizedID }) {
            return "Selected container is not available for this source."
        }
        if !videoEncoderOptions.contains(selectedVideoEncoder) {
            return "Selected video encoder is not available for this format."
        }
        if shouldShowAudioSettings && !audioEncoderOptions.contains(selectedAudioEncoder) {
            return "Selected audio encoder is not available for this format."
        }
        return nil
    }

    var outputFormatOptions: [VideoFormatOption] {
        if availableOutputFormats.isEmpty {
            return VideoConversionEngine.defaultOutputFormats()
        }
        return availableOutputFormats
    }

    var videoEncoderOptions: [VideoEncoderOption] {
        availableVideoEncoders.isEmpty ? [.auto] : availableVideoEncoders
    }

    var audioEncoderOptions: [AudioEncoderOption] {
        if !shouldShowAudioSettings {
            return []
        }
        return availableAudioEncoders.isEmpty ? [.auto] : availableAudioEncoders
    }

    var shouldShowVideoEncoderOption: Bool {
        selectedOutputFormat.supportsVideoEncoderSelection && videoEncoderOptions.count > 1
    }

    var shouldShowAudioSettings: Bool {
        selectedOutputFormat.supportsAudioTrack
    }

    var shouldShowVideoBitRateOption: Bool {
        selectedVideoEncoder.supportsVideoBitRate
    }

    var shouldShowGIFPlaybackSpeedOption: Bool {
        selectedOutputFormat.usesGIFPalettePipeline
    }

    var shouldShowAudioSampleRateOption: Bool {
        shouldShowAudioSettings && selectedAudioEncoder.supportsSampleRate
    }

    var shouldShowAudioBitRateOption: Bool {
        shouldShowAudioSettings && selectedAudioEncoder.supportsAudioBitRate
    }

    var normalizedCustomVideoBitRateKbps: Int? {
        let trimmed = customVideoBitRate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Int(sanitized), value > 0 else { return nil }
        return value
    }

    // MARK: - Image Computed Properties

    var imageSourceIsAnimated: Bool {
        imageSourceFrameCount > 1
    }

    var canConvertImage: Bool {
        imageSourceURL != nil &&
            !isImageConverting &&
            !isAnalyzingImageSource &&
            imageSourceCompatibilityErrorMessage == nil &&
            isImageSettingsValid &&
            availableImageOutputFormats.contains(where: { $0.normalizedID == selectedImageOutputFormat.normalizedID })
    }

    var selectedImageSourceURLs: [URL] {
        guard let imageSourceURL else { return [] }
        return [imageSourceURL] + queuedImageSourceURLs
    }

    var selectedImageFileCount: Int {
        selectedImageSourceURLs.count
    }

    var displayedImageConversionProgress: Double {
        let rawProgress = isImageConverting ? imageConversionProgress : 0
        return rawProgress < 0.01 ? 0 : rawProgress
    }

    var imageProgressPercentageText: String {
        let percent = Int((displayedImageConversionProgress * 100).rounded())
        return "\(max(0, min(percent, 100)))%"
    }

    var imageConversionStatusMessage: String {
        imageConversionStatus.message
    }

    var imageConversionStatusLevel: ConversionStatusLevel {
        imageConversionStatus.level
    }

    var imageOutputFormatOptions: [ImageFormatOption] {
        if availableImageOutputFormats.isEmpty {
            return ImageConversionEngine.defaultOutputFormats()
        }
        return availableImageOutputFormats
    }

    var isImageSettingsValid: Bool {
        imageSettingsValidationMessage == nil
    }

    var shouldShowImageQualityOption: Bool {
        selectedImageOutputFormat.supportsCompressionQuality
    }

    var shouldShowPNGCompressionOption: Bool {
        selectedImageOutputFormat.supportsPNGCompressionLevel
    }

    var shouldShowPreserveAnimationOption: Bool {
        imageSourceIsAnimated && selectedImageOutputFormat.supportsAnimation
    }

    var imageFormatHintMessage: String? {
        if imageSourceIsAnimated && !selectedImageOutputFormat.supportsAnimation {
            return "This format exports only the first frame for animated sources."
        }
        if shouldShowPreserveAnimationOption && !ImageConversionEngine.isFFmpegAvailable() {
            return "ffmpeg is required to preserve animation."
        }
        return nil
    }

    var imageSettingsValidationMessage: String? {
        if let imageSourceCompatibilityErrorMessage {
            return imageSourceCompatibilityErrorMessage
        }
        if imageSourceURL != nil && !availableImageOutputFormats.contains(where: { $0.normalizedID == selectedImageOutputFormat.normalizedID }) {
            return "Selected output format is not available for this source."
        }
        if imageSourceIsAnimated &&
            preserveImageAnimation &&
            selectedImageOutputFormat.supportsAnimation &&
            !ImageConversionEngine.isFFmpegAvailable() {
            return "Animated output requires ffmpeg for the selected format."
        }
        return nil
    }

    // MARK: - Audio Computed Properties

    var canConvertAudio: Bool {
        audioSourceURL != nil &&
            !isAudioConverting &&
            !isAnalyzingAudioSource &&
            audioSettingsValidationMessage == nil &&
            availableAudioOutputFormats.contains(where: { $0.normalizedID == selectedAudioOutputFormat.normalizedID })
    }

    var selectedAudioSourceURLs: [URL] {
        guard let audioSourceURL else { return [] }
        return [audioSourceURL] + queuedAudioSourceURLs
    }

    var selectedAudioFileCount: Int {
        selectedAudioSourceURLs.count
    }

    var displayedAudioConversionProgress: Double {
        let rawProgress = isAudioConverting ? audioConversionProgress : 0
        return rawProgress < 0.01 ? 0 : rawProgress
    }

    var audioProgressPercentageText: String {
        let percent = Int((displayedAudioConversionProgress * 100).rounded())
        return "\(max(0, min(percent, 100)))%"
    }

    var audioConversionStatusMessage: String {
        audioConversionStatus.message
    }

    var audioConversionStatusLevel: ConversionStatusLevel {
        audioConversionStatus.level
    }

    var audioOutputFormatOptions: [AudioFormatOption] {
        if availableAudioOutputFormats.isEmpty && audioSourceURL == nil {
            return VideoConversionEngine.defaultAudioOutputFormats()
        }
        return availableAudioOutputFormats
    }

    var audioOutputEncoderOptions: [AudioEncoderOption] {
        if !availableAudioOutputEncoders.isEmpty {
            return availableAudioOutputEncoders
        }
        return selectedAudioOutputFormat.allowsFFmpegAutomaticAudioCodec ? [.auto] : []
    }

    var shouldShowAudioOutputSampleRateOption: Bool {
        selectedAudioOutputEncoder.supportsSampleRate
    }

    var shouldShowAudioOutputBitRateOption: Bool {
        selectedAudioOutputEncoder.supportsAudioBitRate
    }

    var audioFormatHintMessage: String? {
        if let warning = audioSourceCompatibilityWarningMessage, !warning.isEmpty {
            return warning
        }
        return nil
    }

    var audioSettingsValidationMessage: String? {
        if let audioSourceCompatibilityErrorMessage {
            return audioSourceCompatibilityErrorMessage
        }
        if audioSourceURL != nil &&
            !availableAudioOutputFormats.contains(where: { $0.normalizedID == selectedAudioOutputFormat.normalizedID }) {
            return "Selected output format is not available for this source."
        }
        if !audioOutputEncoderOptions.contains(selectedAudioOutputEncoder) {
            return "Selected audio encoder is not available for this format."
        }
        return nil
    }

    // MARK: - Input Handling

    func preferredImportTypes(for selectedTab: ConverterTab) -> [UTType] {
        switch selectedTab {
        case .video:
            let mkvType = UTType(filenameExtension: "mkv")
            return [.movie, .audiovisualContent, mkvType].compactMap { $0 }
        case .image:
            return [.image]
        case .audio:
            return [.audio, .audiovisualContent]
        case .about:
            return [.item]
        }
    }

    func requestFileImport() {
        isImporting = true
    }

    private func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var unique: [URL] = []

        for url in urls {
            let standardized = url.standardizedFileURL
            let key = sourceIdentifier(for: standardized)
            if seen.insert(key).inserted {
                unique.append(standardized)
            }
        }

        return unique
    }

    func clearSelectedSource() {
        clearSelectedVideoSource()
    }

    func clearSelectedVideoSource() {
        sourceAnalysisTask?.cancel()
        sourceAnalysisTask = nil

        sourceURL = nil
        queuedSourceURLs = []
        convertedURL = nil
        convertedURLs = []
        conversionErrorMessage = nil
        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil
        isAnalyzingSource = false
        currentVideoBatchIndex = 0
        totalVideoBatchCount = 0
        availableOutputFormats = VideoConversionEngine.defaultOutputFormats()

        applyStoredSettings(.init())
        ensureSelectedVideoOutputFormatIsAvailable()
        refreshVideoCodecOptions()
    }

    func clearSelectedImageSource() {
        imageSourceAnalysisTask?.cancel()
        imageSourceAnalysisTask = nil

        imageSourceURL = nil
        queuedImageSourceURLs = []
        imageSourceFrameCount = 0
        imageSourceHasAlpha = false
        convertedImageURL = nil
        convertedImageURLs = []
        imageConversionErrorMessage = nil
        imageSourceCompatibilityErrorMessage = nil
        imageSourceCompatibilityWarningMessage = nil
        isAnalyzingImageSource = false
        currentImageBatchIndex = 0
        totalImageBatchCount = 0
        availableImageOutputFormats = ImageConversionEngine.defaultOutputFormats()

        applyStoredImageSettings(.init())
        ensureSelectedImageOutputFormatIsAvailable()
    }

    func clearSelectedAudioSource() {
        audioSourceAnalysisTask?.cancel()
        audioSourceAnalysisTask = nil

        audioSourceURL = nil
        queuedAudioSourceURLs = []
        convertedAudioURL = nil
        convertedAudioURLs = []
        audioConversionErrorMessage = nil
        audioSourceCompatibilityErrorMessage = nil
        audioSourceCompatibilityWarningMessage = nil
        isAnalyzingAudioSource = false
        currentAudioBatchIndex = 0
        totalAudioBatchCount = 0
        availableAudioOutputFormats = VideoConversionEngine.defaultAudioOutputFormats()

        applyStoredAudioSettings(.init())
        ensureSelectedAudioOutputFormatIsAvailable()
        refreshAudioCodecOptions()
    }

    func handleFileImportResult(_ result: Result<[URL], Error>, for selectedTab: ConverterTab) {
        switch result {
        case .success(let urls):
            let selected = uniqueStandardizedURLs(urls)
            guard !selected.isEmpty else { return }
            switch selectedTab {
            case .video:
                applySelectedVideoSources(selected)
            case .image:
                applySelectedImageSources(selected)
            case .audio:
                applySelectedAudioSources(selected)
            case .about:
                break
            }
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        handleVideoDrop(providers: providers)
    }

    func handleVideoDrop(providers: [NSItemProvider]) -> Bool {
        handleDroppedFiles(providers: providers) { [weak self] urls in
            self?.applySelectedVideoSources(urls)
        }
    }

    func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        handleDroppedFiles(providers: providers) { [weak self] urls in
            self?.applySelectedImageSources(urls)
        }
    }

    func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
        handleDroppedFiles(providers: providers) { [weak self] urls in
            self?.applySelectedAudioSources(urls)
        }
    }

    private func handleDroppedFiles(
        providers: [NSItemProvider],
        onResolvedURLs: @escaping @MainActor ([URL]) -> Void
    ) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var resolvedURLs: [URL] = []

        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }

                var finalURL: URL?

                if let data = item as? Data {
                    finalURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    finalURL = url
                }

                guard let finalURL else { return }

                lock.lock()
                resolvedURLs.append(finalURL)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let unique = self.uniqueStandardizedURLs(resolvedURLs)
            guard !unique.isEmpty else { return }

            Task { @MainActor in
                onResolvedURLs(unique)
            }
        }

        return true
    }

    // MARK: - Conversion Control

    func startConversion() {
        guard !isConverting else { return }
        conversionTask = Task { [weak self] in
            await self?.convert()
        }
    }

    func cancelConversion() {
        guard isConverting else { return }
        conversionTask?.cancel()
    }

    func startImageConversion() {
        guard !isImageConverting else { return }
        imageConversionTask = Task { [weak self] in
            await self?.convertImage()
        }
    }

    func cancelImageConversion() {
        guard isImageConverting else { return }
        imageConversionTask?.cancel()
    }

    func startAudioConversion() {
        guard !isAudioConverting else { return }
        audioConversionTask = Task { [weak self] in
            await self?.convertAudio()
        }
    }

    func cancelAudioConversion() {
        guard isAudioConverting else { return }
        audioConversionTask?.cancel()
    }

    // MARK: - Video Source / Analyze

    private func applySelectedSource(_ url: URL) {
        applySelectedVideoSources([url])
    }

    private func applySelectedVideoSources(_ urls: [URL]) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let firstURL = uniqueURLs.first else { return }

        sourceAnalysisTask?.cancel()
        sourceAnalysisTask = nil

        sourceURL = firstURL
        queuedSourceURLs = Array(uniqueURLs.dropFirst())
        convertedURL = nil
        convertedURLs = []
        conversionErrorMessage = nil
        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil

        let sourceID = sourceIdentifier(for: firstURL)
        let stored = videoSettingsBySourceID[sourceID] ?? VideoConversionSettings()
        applyStoredSettings(stored)

        analyzeSourceCompatibility(for: firstURL)
    }

    private func analyzeSourceCompatibility(for url: URL) {
        isAnalyzingSource = true

        sourceAnalysisTask = Task { [weak self] in
            guard let self else { return }

            let shouldStopSourceAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopSourceAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let capabilities = await VideoConversionEngine.sourceCapabilities(for: url)

            guard !Task.isCancelled else { return }
            guard let currentSourceURL = self.sourceURL else { return }
            guard self.sourceIdentifier(for: url) == self.sourceIdentifier(for: currentSourceURL) else { return }

            self.isAnalyzingSource = false
            self.availableOutputFormats = capabilities.availableOutputFormats
            self.sourceCompatibilityWarningMessage = capabilities.warningMessage
            self.sourceCompatibilityErrorMessage = capabilities.errorMessage

            if let first = capabilities.availableOutputFormats.first,
               !capabilities.availableOutputFormats.contains(where: { $0.normalizedID == self.selectedOutputFormat.normalizedID }) {
                self.selectedOutputFormat = first
            }

            self.ensureSelectedVideoOutputFormatIsAvailable()
            self.refreshVideoCodecOptions()
            self.persistCurrentSettingsIfNeeded()
        }
    }

    // MARK: - Image Source / Analyze

    private func applySelectedImageSource(_ url: URL) {
        applySelectedImageSources([url])
    }

    private func applySelectedImageSources(_ urls: [URL]) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let firstURL = uniqueURLs.first else { return }

        imageSourceAnalysisTask?.cancel()
        imageSourceAnalysisTask = nil

        imageSourceURL = firstURL
        queuedImageSourceURLs = Array(uniqueURLs.dropFirst())
        imageSourceFrameCount = 0
        imageSourceHasAlpha = false
        convertedImageURL = nil
        convertedImageURLs = []
        imageConversionErrorMessage = nil
        imageSourceCompatibilityErrorMessage = nil
        imageSourceCompatibilityWarningMessage = nil

        let sourceID = sourceIdentifier(for: firstURL)
        let stored = imageSettingsBySourceID[sourceID] ?? ImageConversionSettings()
        applyStoredImageSettings(stored)

        analyzeImageSourceCompatibility(for: firstURL)
    }

    private func analyzeImageSourceCompatibility(for url: URL) {
        isAnalyzingImageSource = true

        imageSourceAnalysisTask = Task { [weak self] in
            guard let self else { return }

            let shouldStopSourceAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopSourceAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let capabilities = await ImageConversionEngine.sourceCapabilities(for: url)

            guard !Task.isCancelled else { return }
            guard let currentSourceURL = self.imageSourceURL else { return }
            guard self.sourceIdentifier(for: url) == self.sourceIdentifier(for: currentSourceURL) else { return }

            self.isAnalyzingImageSource = false
            self.availableImageOutputFormats = capabilities.availableOutputFormats.isEmpty
                ? ImageConversionEngine.defaultOutputFormats()
                : capabilities.availableOutputFormats
            self.imageSourceCompatibilityWarningMessage = capabilities.warningMessage
            self.imageSourceCompatibilityErrorMessage = capabilities.errorMessage
            self.imageSourceFrameCount = capabilities.frameCount
            self.imageSourceHasAlpha = capabilities.hasAlpha

            if let first = capabilities.availableOutputFormats.first,
               !capabilities.availableOutputFormats.contains(where: { $0.normalizedID == self.selectedImageOutputFormat.normalizedID }) {
                self.selectedImageOutputFormat = first
            }

            self.ensureSelectedImageOutputFormatIsAvailable()
            self.persistCurrentImageSettingsIfNeeded()
        }
    }

    // MARK: - Audio Source / Analyze

    private func applySelectedAudioSource(_ url: URL) {
        applySelectedAudioSources([url])
    }

    private func applySelectedAudioSources(_ urls: [URL]) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let firstURL = uniqueURLs.first else { return }

        audioSourceAnalysisTask?.cancel()
        audioSourceAnalysisTask = nil

        audioSourceURL = firstURL
        queuedAudioSourceURLs = Array(uniqueURLs.dropFirst())
        convertedAudioURL = nil
        convertedAudioURLs = []
        audioConversionErrorMessage = nil
        audioSourceCompatibilityErrorMessage = nil
        audioSourceCompatibilityWarningMessage = nil

        let sourceID = sourceIdentifier(for: firstURL)
        let stored = audioSettingsBySourceID[sourceID] ?? AudioConversionSettings()
        applyStoredAudioSettings(stored)

        analyzeAudioSourceCompatibility(for: firstURL)
    }

    private func analyzeAudioSourceCompatibility(for url: URL) {
        isAnalyzingAudioSource = true

        audioSourceAnalysisTask = Task { [weak self] in
            guard let self else { return }

            let shouldStopSourceAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopSourceAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let capabilities = await VideoConversionEngine.sourceCapabilitiesForAudio(for: url)

            guard !Task.isCancelled else { return }
            guard let currentSourceURL = self.audioSourceURL else { return }
            guard self.sourceIdentifier(for: url) == self.sourceIdentifier(for: currentSourceURL) else { return }

            self.isAnalyzingAudioSource = false
            self.availableAudioOutputFormats = capabilities.availableOutputFormats
            self.audioSourceCompatibilityWarningMessage = capabilities.warningMessage
            self.audioSourceCompatibilityErrorMessage = capabilities.errorMessage

            if let first = capabilities.availableOutputFormats.first,
               !capabilities.availableOutputFormats.contains(where: { $0.normalizedID == self.selectedAudioOutputFormat.normalizedID }) {
                self.selectedAudioOutputFormat = first
            }

            self.ensureSelectedAudioOutputFormatIsAvailable()
            self.refreshAudioCodecOptions()
            self.persistCurrentAudioSettingsIfNeeded()
        }
    }

    // MARK: - Build Settings

    private func buildVideoOutputSettings() throws -> VideoOutputSettings {
        let videoBitRateKbps: Int?
        if shouldShowVideoBitRateOption {
            switch selectedVideoBitRate {
            case .auto:
                videoBitRateKbps = nil
            case .custom:
                guard let custom = normalizedCustomVideoBitRateKbps else {
                    throw ConversionError.invalidCustomVideoBitRate(customVideoBitRate)
                }
                videoBitRateKbps = custom
            default:
                videoBitRateKbps = selectedVideoBitRate.kbps
            }
        } else {
            videoBitRateKbps = nil
        }

        return VideoOutputSettings(
            containerFormat: selectedOutputFormat,
            videoCodecCandidates: selectedVideoEncoder.codecCandidates,
            useHEVCTag: selectedVideoEncoder.usesHEVCCodec,
            resolution: selectedResolution.dimensions,
            frameRate: selectedFrameRate.fps,
            gifPlaybackSpeed: shouldShowGIFPlaybackSpeedOption ? selectedGIFPlaybackSpeed.multiplier : nil,
            videoBitRateKbps: videoBitRateKbps,
            audioCodecCandidates: shouldShowAudioSettings ? selectedAudioEncoder.codecCandidates : [],
            audioChannels: shouldShowAudioSettings ? selectedAudioMode.channelCount : nil,
            sampleRate: shouldShowAudioSampleRateOption ? selectedSampleRate.hertz : nil,
            audioBitRateKbps: shouldShowAudioBitRateOption ? selectedAudioBitRate.kbps : nil
        )
    }

    private func buildImageOutputSettings() -> ImageOutputSettings {
        let compressionQuality: Double?
        if selectedImageOutputFormat.supportsCompressionQuality {
            compressionQuality = selectedImageQuality.compressionQuality
        } else {
            compressionQuality = nil
        }

        let pngCompressionLevel: Int?
        if selectedImageOutputFormat.supportsPNGCompressionLevel {
            pngCompressionLevel = selectedPNGCompressionLevel.level
        } else {
            pngCompressionLevel = nil
        }

        return ImageOutputSettings(
            containerFormat: selectedImageOutputFormat,
            resolution: selectedImageResolution.dimensions,
            compressionQuality: compressionQuality,
            pngCompressionLevel: pngCompressionLevel,
            preserveAnimation: preserveImageAnimation,
            sourceIsAnimated: imageSourceIsAnimated
        )
    }

    private func buildAudioOutputSettings() -> AudioOutputSettings {
        AudioOutputSettings(
            containerFormat: selectedAudioOutputFormat,
            audioCodecCandidates: selectedAudioOutputEncoder.codecCandidates,
            audioChannels: selectedAudioOutputMode.channelCount,
            sampleRate: shouldShowAudioOutputSampleRateOption ? selectedAudioOutputSampleRate.hertz : nil,
            audioBitRateKbps: shouldShowAudioOutputBitRateOption ? selectedAudioOutputBitRate.kbps : nil
        )
    }

    // MARK: - Conversion State / Errors

    private func prepareConversionStartState() {
        isConverting = true
        convertedURL = nil
        convertedURLs = []
        conversionErrorMessage = nil
        conversionProgress = 0
    }

    private func prepareImageConversionStartState() {
        isImageConverting = true
        convertedImageURL = nil
        convertedImageURLs = []
        imageConversionErrorMessage = nil
        imageConversionProgress = 0
    }

    private func prepareAudioConversionStartState() {
        isAudioConverting = true
        convertedAudioURL = nil
        convertedAudioURLs = []
        audioConversionErrorMessage = nil
        audioConversionProgress = 0
    }

    private func applyConversionError(_ error: Error) {
        if case ConversionError.exportCancelled = error {
            conversionErrorMessage = nil
            return
        }

        conversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

        if let conversionError = error as? ConversionError {
            print("Conversion failed: \(conversionError.debugInfo)")
        } else {
            print("Conversion failed: \(error.localizedDescription)")
        }
    }

    private func applyImageConversionError(_ error: Error) {
        imageConversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        print("Image conversion failed: \(imageConversionErrorMessage ?? error.localizedDescription)")
    }

    private func applyAudioConversionError(_ error: Error) {
        if case ConversionError.exportCancelled = error {
            audioConversionErrorMessage = nil
            return
        }

        audioConversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        print("Audio conversion failed: \(audioConversionErrorMessage ?? error.localizedDescription)")
    }

    // MARK: - Video Convert

    private func convert() async {
        defer { conversionTask = nil }

        guard canConvert, let sourceURL else {
            if sourceURL == nil {
                print("No file to convert.")
            }
            return
        }

        let outputSettings: VideoOutputSettings
        do {
            outputSettings = try buildVideoOutputSettings()
        } catch {
            applyConversionError(error)
            return
        }

        prepareConversionStartState()
        let sourceURLs = [sourceURL] + queuedSourceURLs
        totalVideoBatchCount = sourceURLs.count
        currentVideoBatchIndex = 0

        do {
            defer {
                isConverting = false
                currentVideoBatchIndex = 0
                totalVideoBatchCount = 0
            }
            try Task.checkCancellation()

            let outputDirectory = try VideoConversionEngine.sandboxOutputDirectory(
                bundleIdentifier: Bundle.main.bundleIdentifier
            )

            for (index, currentSourceURL) in sourceURLs.enumerated() {
                try Task.checkCancellation()
                currentVideoBatchIndex = index + 1

                let shouldStopSourceAccessing = currentSourceURL.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopSourceAccessing {
                        currentSourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                let destinationURL = VideoConversionEngine.uniqueOutputURL(
                    for: currentSourceURL,
                    format: selectedOutputFormat,
                    in: outputDirectory
                )
                let workingOutputURL = VideoConversionEngine.temporaryOutputURL(
                    for: currentSourceURL,
                    format: selectedOutputFormat
                )
                defer {
                    if FileManager.default.fileExists(atPath: workingOutputURL.path) {
                        try? FileManager.default.removeItem(at: workingOutputURL)
                    }
                }

                let output = try await VideoConversionEngine.convert(
                    inputURL: currentSourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil
                ) { [weak self] progress in
                    let base = Double(index)
                    let total = Double(max(sourceURLs.count, 1))
                    await self?.updateConversionProgress((base + progress) / total)
                }
                try Task.checkCancellation()

                let savedURL = try VideoConversionEngine.saveConvertedOutput(from: output, to: destinationURL)
                convertedURL = savedURL
                convertedURLs.append(savedURL)
            }

            conversionProgress = 1
        } catch is CancellationError {
            conversionProgress = 0
            conversionErrorMessage = nil
        } catch ConversionError.exportCancelled {
            conversionProgress = 0
            conversionErrorMessage = nil
        } catch {
            applyConversionError(error)
        }
    }

    // MARK: - Image Convert

    private func convertImage() async {
        defer { imageConversionTask = nil }

        guard canConvertImage, let sourceURL = imageSourceURL else {
            if imageSourceURL == nil {
                print("No image file to convert.")
            }
            return
        }

        let outputSettings = buildImageOutputSettings()
        prepareImageConversionStartState()
        let sourceURLs = [sourceURL] + queuedImageSourceURLs
        totalImageBatchCount = sourceURLs.count
        currentImageBatchIndex = 0

        do {
            defer {
                isImageConverting = false
                currentImageBatchIndex = 0
                totalImageBatchCount = 0
            }
            try Task.checkCancellation()

            let outputDirectory = try VideoConversionEngine.sandboxOutputDirectory(
                bundleIdentifier: Bundle.main.bundleIdentifier
            )

            for (index, currentSourceURL) in sourceURLs.enumerated() {
                try Task.checkCancellation()
                currentImageBatchIndex = index + 1

                let shouldStopSourceAccessing = currentSourceURL.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopSourceAccessing {
                        currentSourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                let destinationURL = ImageConversionEngine.uniqueOutputURL(
                    for: currentSourceURL,
                    format: selectedImageOutputFormat,
                    in: outputDirectory
                )
                let workingOutputURL = ImageConversionEngine.temporaryOutputURL(
                    for: currentSourceURL,
                    format: selectedImageOutputFormat
                )
                defer {
                    if FileManager.default.fileExists(atPath: workingOutputURL.path) {
                        try? FileManager.default.removeItem(at: workingOutputURL)
                    }
                }

                let output = try await ImageConversionEngine.convert(
                    inputURL: currentSourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings
                ) { [weak self] progress in
                    let base = Double(index)
                    let total = Double(max(sourceURLs.count, 1))
                    await self?.updateImageConversionProgress((base + progress) / total)
                }
                try Task.checkCancellation()

                let savedURL = try VideoConversionEngine.saveConvertedOutput(from: output, to: destinationURL)
                convertedImageURL = savedURL
                convertedImageURLs.append(savedURL)
            }

            imageConversionProgress = 1
        } catch is CancellationError {
            imageConversionProgress = 0
            imageConversionErrorMessage = nil
        } catch {
            applyImageConversionError(error)
        }
    }

    // MARK: - Audio Convert

    private func convertAudio() async {
        defer { audioConversionTask = nil }

        guard canConvertAudio, let sourceURL = audioSourceURL else {
            if audioSourceURL == nil {
                print("No audio file to convert.")
            }
            return
        }

        let outputSettings = buildAudioOutputSettings()
        prepareAudioConversionStartState()
        let sourceURLs = [sourceURL] + queuedAudioSourceURLs
        totalAudioBatchCount = sourceURLs.count
        currentAudioBatchIndex = 0

        do {
            defer {
                isAudioConverting = false
                currentAudioBatchIndex = 0
                totalAudioBatchCount = 0
            }
            try Task.checkCancellation()

            let outputDirectory = try VideoConversionEngine.sandboxOutputDirectory(
                bundleIdentifier: Bundle.main.bundleIdentifier
            )

            for (index, currentSourceURL) in sourceURLs.enumerated() {
                try Task.checkCancellation()
                currentAudioBatchIndex = index + 1

                let shouldStopSourceAccessing = currentSourceURL.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopSourceAccessing {
                        currentSourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                let destinationURL = VideoConversionEngine.uniqueOutputURL(
                    for: currentSourceURL,
                    format: selectedAudioOutputFormat,
                    in: outputDirectory
                )
                let workingOutputURL = VideoConversionEngine.temporaryOutputURL(
                    for: currentSourceURL,
                    format: selectedAudioOutputFormat
                )
                defer {
                    if FileManager.default.fileExists(atPath: workingOutputURL.path) {
                        try? FileManager.default.removeItem(at: workingOutputURL)
                    }
                }

                let output = try await VideoConversionEngine.convertAudio(
                    inputURL: currentSourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil
                ) { [weak self] progress in
                    let base = Double(index)
                    let total = Double(max(sourceURLs.count, 1))
                    await self?.updateAudioConversionProgress((base + progress) / total)
                }
                try Task.checkCancellation()

                let savedURL = try VideoConversionEngine.saveConvertedOutput(from: output, to: destinationURL)
                convertedAudioURL = savedURL
                convertedAudioURLs.append(savedURL)
            }

            audioConversionProgress = 1
        } catch is CancellationError {
            audioConversionProgress = 0
            audioConversionErrorMessage = nil
        } catch ConversionError.exportCancelled {
            audioConversionProgress = 0
            audioConversionErrorMessage = nil
        } catch {
            applyAudioConversionError(error)
        }
    }

    // MARK: - Progress

    private func updateConversionProgress(_ rawProgress: Double) {
        conversionProgress = clampedProgress(rawProgress)
    }

    private func updateImageConversionProgress(_ rawProgress: Double) {
        imageConversionProgress = clampedProgress(rawProgress)
    }

    private func updateAudioConversionProgress(_ rawProgress: Double) {
        audioConversionProgress = clampedProgress(rawProgress)
    }

    // MARK: - Persistence

    private func clampedProgress(_ rawProgress: Double) -> Double {
        min(max(rawProgress, 0), 1)
    }

    private func sourceIdentifier(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func makeDeferredMainActorTask(
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            action(self)
        }
    }

    private func saveSettings<Value: Encodable>(
        _ settings: Value,
        forKey storageKey: String,
        failureContext: String
    ) {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("\(failureContext): \(error.localizedDescription)")
        }
    }

    private func loadSettings<Value: Decodable>(
        _ type: Value.Type,
        forKey storageKey: String,
        failureContext: String
    ) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("\(failureContext): \(error.localizedDescription)")
            return nil
        }
    }

    private func buildConversionStatus(
        isConverting: Bool,
        currentBatchIndex: Int,
        totalBatchCount: Int,
        isAnalyzingSource: Bool,
        conversionErrorMessage: String?,
        validationMessage: String?,
        compatibilityWarningMessage: String?,
        hintMessage: String? = nil
    ) -> (message: String, level: ConversionStatusLevel) {
        if isConverting {
            if totalBatchCount > 1 {
                let current = max(1, currentBatchIndex)
                return ("Converting file \(current)/\(totalBatchCount)...", .normal)
            }
            return ("Conversion in progress...", .normal)
        }

        if isAnalyzingSource {
            return ("Analyzing source compatibility...", .normal)
        }

        if let conversionErrorMessage, !conversionErrorMessage.isEmpty {
            return (conversionErrorMessage, .error)
        }

        if let validationMessage {
            return (validationMessage, .error)
        }

        if let compatibilityWarningMessage, !compatibilityWarningMessage.isEmpty {
            return (compatibilityWarningMessage, .warning)
        }

        if let hintMessage, !hintMessage.isEmpty {
            return (hintMessage, .warning)
        }

        return ("Ready", .normal)
    }

    private func scheduleVideoFormatChangeHandling() {
        pendingVideoFormatChangeTask?.cancel()
        pendingVideoFormatChangeTask = makeDeferredMainActorTask { viewModel in
            viewModel.refreshVideoCodecOptions()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    private func scheduleVideoOptionNormalizationAndPersist() {
        pendingVideoOptionNormalizationTask?.cancel()
        pendingVideoOptionNormalizationTask = makeDeferredMainActorTask { viewModel in
            viewModel.normalizeVideoOptionDependencies()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    private func scheduleAudioFormatChangeHandling() {
        pendingAudioFormatChangeTask?.cancel()
        pendingAudioFormatChangeTask = makeDeferredMainActorTask { viewModel in
            viewModel.refreshAudioCodecOptions()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

    private func scheduleAudioOptionNormalizationAndPersist() {
        pendingAudioOptionNormalizationTask?.cancel()
        pendingAudioOptionNormalizationTask = makeDeferredMainActorTask { viewModel in
            viewModel.normalizeAudioOptionDependencies()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

    private func persistCurrentSettingsIfNeeded() {
        persistCurrentVideoSettingsIfNeeded()
    }

    private func persistCurrentVideoSettingsIfNeeded() {
        guard !isApplyingStoredSettings, let sourceURL else { return }

        videoSettingsBySourceID[sourceIdentifier(for: sourceURL)] = VideoConversionSettings(
            outputFormatID: selectedOutputFormat.id,
            videoEncoder: selectedVideoEncoder,
            resolution: selectedResolution,
            frameRate: selectedFrameRate,
            gifPlaybackSpeed: selectedGIFPlaybackSpeed,
            videoBitRate: selectedVideoBitRate,
            customVideoBitRate: customVideoBitRate,
            audioEncoder: selectedAudioEncoder,
            audioMode: selectedAudioMode,
            sampleRate: selectedSampleRate,
            audioBitRate: selectedAudioBitRate
        )
        savePersistedSettings()
    }

    private func persistCurrentImageSettingsIfNeeded() {
        guard !isApplyingStoredImageSettings, let imageSourceURL else { return }

        imageSettingsBySourceID[sourceIdentifier(for: imageSourceURL)] = ImageConversionSettings(
            outputFormatID: selectedImageOutputFormat.id,
            resolution: selectedImageResolution,
            quality: selectedImageQuality,
            pngCompressionLevel: selectedPNGCompressionLevel,
            preserveAnimation: preserveImageAnimation
        )
        savePersistedImageSettings()
    }

    private func persistCurrentAudioSettingsIfNeeded() {
        guard !isApplyingStoredAudioSettings, let audioSourceURL else { return }

        audioSettingsBySourceID[sourceIdentifier(for: audioSourceURL)] = AudioConversionSettings(
            outputFormatID: selectedAudioOutputFormat.id,
            audioEncoder: selectedAudioOutputEncoder,
            audioMode: selectedAudioOutputMode,
            sampleRate: selectedAudioOutputSampleRate,
            audioBitRate: selectedAudioOutputBitRate
        )
        savePersistedAudioSettings()
    }

    private func applyStoredSettings(_ settings: VideoConversionSettings) {
        isApplyingStoredSettings = true
        defer { isApplyingStoredSettings = false }

        if let normalizedID = VideoFormatOption.legacyNormalizedID(from: settings.outputFormatID),
           let matchingFormat = outputFormatOptions.first(where: { $0.normalizedID == normalizedID }) {
            selectedOutputFormat = matchingFormat
        }
        selectedVideoEncoder = settings.videoEncoder
        selectedResolution = settings.resolution
        selectedFrameRate = settings.frameRate
        selectedGIFPlaybackSpeed = settings.gifPlaybackSpeed
        selectedVideoBitRate = settings.videoBitRate
        customVideoBitRate = settings.customVideoBitRate
        selectedAudioEncoder = settings.audioEncoder
        selectedAudioMode = settings.audioMode
        selectedSampleRate = settings.sampleRate
        selectedAudioBitRate = settings.audioBitRate
        ensureSelectedVideoOutputFormatIsAvailable()
        refreshVideoCodecOptions()
    }

    private func applyStoredImageSettings(_ settings: ImageConversionSettings) {
        isApplyingStoredImageSettings = true
        defer { isApplyingStoredImageSettings = false }

        if let matchingFormat = imageOutputFormatOptions.first(where: { $0.normalizedID == settings.outputFormatID.lowercased() }) {
            selectedImageOutputFormat = matchingFormat
        }
        selectedImageResolution = settings.resolution
        selectedImageQuality = settings.quality
        selectedPNGCompressionLevel = settings.pngCompressionLevel
        preserveImageAnimation = settings.preserveAnimation
        ensureSelectedImageOutputFormatIsAvailable()
    }

    private func applyStoredAudioSettings(_ settings: AudioConversionSettings) {
        isApplyingStoredAudioSettings = true
        defer { isApplyingStoredAudioSettings = false }

        if let matchingFormat = audioOutputFormatOptions.first(where: { $0.normalizedID == settings.outputFormatID.lowercased() }) {
            selectedAudioOutputFormat = matchingFormat
        }
        selectedAudioOutputEncoder = settings.audioEncoder
        selectedAudioOutputMode = settings.audioMode
        selectedAudioOutputSampleRate = settings.sampleRate
        selectedAudioOutputBitRate = settings.audioBitRate
        ensureSelectedAudioOutputFormatIsAvailable()
        refreshAudioCodecOptions()
    }

    private func ensureSelectedImageOutputFormatIsAvailable() {
        let options = imageOutputFormatOptions
        guard !options.isEmpty else { return }
        if !options.contains(where: { $0.normalizedID == selectedImageOutputFormat.normalizedID }), let first = options.first {
            selectedImageOutputFormat = first
        }
    }

    private func ensureSelectedAudioOutputFormatIsAvailable() {
        let options = audioOutputFormatOptions
        guard !options.isEmpty else { return }
        if !options.contains(where: { $0.normalizedID == selectedAudioOutputFormat.normalizedID }),
           let preferred = AudioFormatOption.defaultSelection(from: options) {
            selectedAudioOutputFormat = preferred
        }
    }

    private func ensureSelectedVideoOutputFormatIsAvailable() {
        let options = outputFormatOptions
        guard !options.isEmpty else { return }
        if !options.contains(where: { $0.normalizedID == selectedOutputFormat.normalizedID }), let preferred = VideoFormatOption.defaultSelection(from: options) {
            selectedOutputFormat = preferred
        }
    }

    private func refreshVideoCodecOptions() {
        let format = selectedOutputFormat
        availableVideoEncoders = VideoConversionEngine.availableVideoEncoders(for: format)
        availableAudioEncoders = format.supportsAudioTrack
            ? VideoConversionEngine.availableAudioEncoders(for: format)
            : []

        if let preferredVideo = preferredVideoEncoder(from: availableVideoEncoders),
           !availableVideoEncoders.contains(selectedVideoEncoder) {
            selectedVideoEncoder = preferredVideo
        }
        if format.supportsAudioTrack,
           let preferredAudio = preferredAudioEncoder(from: availableAudioEncoders),
           !availableAudioEncoders.contains(selectedAudioEncoder) {
            selectedAudioEncoder = preferredAudio
        }

        normalizeVideoOptionDependencies()
    }

    private func refreshAudioCodecOptions() {
        let format = selectedAudioOutputFormat
        availableAudioOutputEncoders = VideoConversionEngine.availableAudioEncoders(for: format)

        let effectiveOptions = availableAudioOutputEncoders.isEmpty && format.allowsFFmpegAutomaticAudioCodec
            ? [.auto]
            : availableAudioOutputEncoders

        if let preferred = preferredAudioOutputEncoder(for: format, from: effectiveOptions),
           !effectiveOptions.contains(selectedAudioOutputEncoder) {
            selectedAudioOutputEncoder = preferred
        }

        normalizeAudioOptionDependencies()
    }

    private func preferredVideoEncoder(from options: [VideoEncoderOption]) -> VideoEncoderOption? {
        guard !options.isEmpty else { return nil }
        if options.contains(.h264GPU) { return .h264GPU }
        if options.contains(.h264CPU) { return .h264CPU }
        if options.contains(.auto) { return .auto }
        return options.first
    }

    private func preferredAudioEncoder(from options: [AudioEncoderOption]) -> AudioEncoderOption? {
        guard !options.isEmpty else { return nil }
        if options.contains(.aac) { return .aac }
        if options.contains(.auto) { return .auto }
        return options.first
    }

    private func preferredAudioOutputEncoder(for format: AudioFormatOption, from options: [AudioEncoderOption]) -> AudioEncoderOption? {
        guard !options.isEmpty else { return nil }

        switch format.fileExtension.lowercased() {
        case "m4a", "aac":
            if options.contains(.aac) { return .aac }
        case "mp3":
            if options.contains(.mp3) { return .mp3 }
        case "wav", "aiff", "aif", "caf":
            if options.contains(.pcm) { return .pcm }
        case "flac":
            if options.contains(.flac) { return .flac }
        case "opus", "ogg", "oga":
            if options.contains(.opus) { return .opus }
        default:
            break
        }

        if options.contains(.aac) { return .aac }
        if options.contains(.mp3) { return .mp3 }
        if options.contains(.auto) { return .auto }
        return options.first
    }

    private func normalizeVideoOptionDependencies() {
        if !selectedVideoEncoder.supportsVideoBitRate && selectedVideoBitRate != .auto {
            selectedVideoBitRate = .auto
        }

        if !shouldShowAudioSettings {
            if selectedAudioEncoder != .auto {
                selectedAudioEncoder = .auto
            }
            if selectedAudioMode != .auto {
                selectedAudioMode = .auto
            }
            if selectedAudioBitRate != .auto {
                selectedAudioBitRate = .auto
            }
            return
        }

        if !selectedAudioEncoder.supportsAudioBitRate && selectedAudioBitRate != .auto {
            selectedAudioBitRate = .auto
        }
    }

    private func normalizeAudioOptionDependencies() {
        let options = audioOutputEncoderOptions
        if !options.isEmpty,
           !options.contains(selectedAudioOutputEncoder),
           let preferred = preferredAudioOutputEncoder(for: selectedAudioOutputFormat, from: options) {
            selectedAudioOutputEncoder = preferred
        }

        if !selectedAudioOutputEncoder.supportsAudioBitRate && selectedAudioOutputBitRate != .auto {
            selectedAudioOutputBitRate = .auto
        }
    }

    private func savePersistedSettings() {
        let persisted = videoSettingsBySourceID.mapValues { PersistedVideoConversionSettings(from: $0) }
        saveSettings(
            persisted,
            forKey: videoSettingsStorageKey,
            failureContext: "Failed to persist video settings"
        )
    }

    private func savePersistedImageSettings() {
        let persisted = imageSettingsBySourceID.mapValues { PersistedImageConversionSettings(from: $0) }
        saveSettings(
            persisted,
            forKey: imageSettingsStorageKey,
            failureContext: "Failed to persist image settings"
        )
    }

    private func savePersistedAudioSettings() {
        let persisted = audioSettingsBySourceID.mapValues { PersistedAudioConversionSettings(from: $0) }
        saveSettings(
            persisted,
            forKey: audioSettingsStorageKey,
            failureContext: "Failed to persist audio settings"
        )
    }

    private func loadPersistedSettings() -> [String: VideoConversionSettings] {
        guard let decoded = loadSettings(
            [String: PersistedVideoConversionSettings].self,
            forKey: videoSettingsStorageKey,
            failureContext: "Failed to load persisted video settings"
        ) else {
            return [:]
        }
        return decoded.mapValues { $0.restoredSettings }
    }

    private func loadPersistedImageSettings() -> [String: ImageConversionSettings] {
        guard let decoded = loadSettings(
            [String: PersistedImageConversionSettings].self,
            forKey: imageSettingsStorageKey,
            failureContext: "Failed to load persisted image settings"
        ) else {
            return [:]
        }
        return decoded.mapValues { $0.restoredSettings }
    }

    private func loadPersistedAudioSettings() -> [String: AudioConversionSettings] {
        guard let decoded = loadSettings(
            [String: PersistedAudioConversionSettings].self,
            forKey: audioSettingsStorageKey,
            failureContext: "Failed to load persisted audio settings"
        ) else {
            return [:]
        }
        return decoded.mapValues { $0.restoredSettings }
    }

    // MARK: - Status

    private var conversionStatus: (message: String, level: ConversionStatusLevel) {
        buildConversionStatus(
            isConverting: isConverting,
            currentBatchIndex: currentVideoBatchIndex,
            totalBatchCount: totalVideoBatchCount,
            isAnalyzingSource: isAnalyzingSource,
            conversionErrorMessage: conversionErrorMessage,
            validationMessage: videoSettingsValidationMessage,
            compatibilityWarningMessage: sourceCompatibilityWarningMessage
        )
    }

    private var imageConversionStatus: (message: String, level: ConversionStatusLevel) {
        buildConversionStatus(
            isConverting: isImageConverting,
            currentBatchIndex: currentImageBatchIndex,
            totalBatchCount: totalImageBatchCount,
            isAnalyzingSource: isAnalyzingImageSource,
            conversionErrorMessage: imageConversionErrorMessage,
            validationMessage: imageSettingsValidationMessage,
            compatibilityWarningMessage: imageSourceCompatibilityWarningMessage,
            hintMessage: imageFormatHintMessage
        )
    }

    private var audioConversionStatus: (message: String, level: ConversionStatusLevel) {
        buildConversionStatus(
            isConverting: isAudioConverting,
            currentBatchIndex: currentAudioBatchIndex,
            totalBatchCount: totalAudioBatchCount,
            isAnalyzingSource: isAnalyzingAudioSource,
            conversionErrorMessage: audioConversionErrorMessage,
            validationMessage: audioSettingsValidationMessage,
            compatibilityWarningMessage: audioSourceCompatibilityWarningMessage,
            hintMessage: audioFormatHintMessage
        )
    }
}
