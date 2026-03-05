import Combine
import AppKit
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

    // MARK: - Input Handling

    func preferredImportTypes(for selectedTab: ConverterTab) -> [UTType] {
        switch selectedTab {
        case .video:
            let mkvType = UTType(filenameExtension: "mkv")
            return [.movie, .video, mkvType].compactMap { $0 }
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
        ContentViewModelSupport.uniqueStandardizedURLs(urls)
    }

    private func isVideoInputURL(_ url: URL) -> Bool {
        ContentViewModelSupport.isVideoInputURL(url)
    }

    private func isImageInputURL(_ url: URL) -> Bool {
        ContentViewModelSupport.isImageInputURL(url)
    }

    private func isAudioInputURL(_ url: URL) -> Bool {
        ContentViewModelSupport.isAudioInputURL(url)
    }

    private func cancelTask(_ task: inout Task<Void, Never>?) {
        task?.cancel()
        task = nil
    }

    func clearSelectedSource() {
        clearSelectedVideoSource()
    }

    func clearSelectedVideoSource() {
        cancelTask(&sourceAnalysisTask)

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
        cancelTask(&imageSourceAnalysisTask)

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
        cancelTask(&audioSourceAnalysisTask)

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
                let filtered = selected.filter(isVideoInputURL)
                guard !filtered.isEmpty else { return }
                applySelectedVideoSources(filtered)
            case .image:
                let filtered = selected.filter(isImageInputURL)
                guard !filtered.isEmpty else { return }
                applySelectedImageSources(filtered)
            case .audio:
                let filtered = selected.filter(isAudioInputURL)
                guard !filtered.isEmpty else { return }
                applySelectedAudioSources(filtered)
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
        handleDroppedFiles(providers: providers, accept: isVideoInputURL) { [weak self] urls in
            self?.applySelectedVideoSources(urls)
        }
    }

    func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        handleDroppedFiles(providers: providers, accept: isImageInputURL) { [weak self] urls in
            self?.applySelectedImageSources(urls)
        }
    }

    func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
        handleDroppedFiles(providers: providers, accept: isAudioInputURL) { [weak self] urls in
            self?.applySelectedAudioSources(urls)
        }
    }

    private func handleDroppedFiles(
        providers: [NSItemProvider],
        accept: @escaping (URL) -> Bool,
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
            let accepted = unique.filter(accept)
            guard !accepted.isEmpty else { return }

            Task { @MainActor in
                onResolvedURLs(accepted)
            }
        }

        return true
    }

    func moveSelectedVideoSource(from draggedURL: URL, to targetURL: URL) {
        guard !isConverting else { return }
        let previousPrimaryID = sourceURL.map(sourceIdentifier(for:))
        guard let reordered = reorderedURLsByMoving(draggedURL, to: targetURL, in: selectedVideoSourceURLs) else {
            return
        }

        sourceURL = reordered.first
        queuedSourceURLs = Array(reordered.dropFirst())

        guard let newPrimarySourceURL = sourceURL else { return }
        guard sourceIdentifier(for: newPrimarySourceURL) != previousPrimaryID else { return }

        cancelTask(&sourceAnalysisTask)
        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil

        let sourceID = sourceIdentifier(for: newPrimarySourceURL)
        let stored = videoSettingsBySourceID[sourceID] ?? VideoConversionSettings()
        applyStoredSettings(stored)
        analyzeSourceCompatibility(for: selectedVideoSourceURLs)
    }

    func moveSelectedImageSource(from draggedURL: URL, to targetURL: URL) {
        guard !isImageConverting else { return }
        let previousPrimaryID = imageSourceURL.map(sourceIdentifier(for:))
        guard let reordered = reorderedURLsByMoving(draggedURL, to: targetURL, in: selectedImageSourceURLs) else {
            return
        }

        imageSourceURL = reordered.first
        queuedImageSourceURLs = Array(reordered.dropFirst())

        guard let newPrimarySourceURL = imageSourceURL else { return }
        guard sourceIdentifier(for: newPrimarySourceURL) != previousPrimaryID else { return }

        cancelTask(&imageSourceAnalysisTask)
        imageSourceFrameCount = 0
        imageSourceHasAlpha = false
        imageSourceCompatibilityErrorMessage = nil
        imageSourceCompatibilityWarningMessage = nil

        let sourceID = sourceIdentifier(for: newPrimarySourceURL)
        let stored = imageSettingsBySourceID[sourceID] ?? ImageConversionSettings()
        applyStoredImageSettings(stored)
        analyzeImageSourceCompatibility(for: selectedImageSourceURLs)
    }

    func moveSelectedAudioSource(from draggedURL: URL, to targetURL: URL) {
        guard !isAudioConverting else { return }
        let previousPrimaryID = audioSourceURL.map(sourceIdentifier(for:))
        guard let reordered = reorderedURLsByMoving(draggedURL, to: targetURL, in: selectedAudioSourceURLs) else {
            return
        }

        audioSourceURL = reordered.first
        queuedAudioSourceURLs = Array(reordered.dropFirst())

        guard let newPrimarySourceURL = audioSourceURL else { return }
        guard sourceIdentifier(for: newPrimarySourceURL) != previousPrimaryID else { return }

        cancelTask(&audioSourceAnalysisTask)
        audioSourceCompatibilityErrorMessage = nil
        audioSourceCompatibilityWarningMessage = nil

        let sourceID = sourceIdentifier(for: newPrimarySourceURL)
        let stored = audioSettingsBySourceID[sourceID] ?? AudioConversionSettings()
        applyStoredAudioSettings(stored)
        analyzeAudioSourceCompatibility(for: selectedAudioSourceURLs)
    }

    private func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        ContentViewModelSupport.reorderedURLsByMoving(draggedURL, to: targetURL, in: urls)
    }

    private func labeledCapabilityMessage(_ message: String, for sourceURL: URL, totalCount: Int) -> String {
        ContentViewModelSupport.labeledCapabilityMessage(message, for: sourceURL, totalCount: totalCount)
    }

    private func joinedCapabilityMessages(_ messages: [String]) -> String? {
        ContentViewModelSupport.joinedCapabilityMessages(messages)
    }

    private func intersectVideoFormats(_ lhs: [VideoFormatOption], _ rhs: [VideoFormatOption]) -> [VideoFormatOption] {
        ContentViewModelSupport.intersectVideoFormats(lhs, rhs)
    }

    private func intersectImageFormats(_ lhs: [ImageFormatOption], _ rhs: [ImageFormatOption]) -> [ImageFormatOption] {
        ContentViewModelSupport.intersectImageFormats(lhs, rhs)
    }

    private func intersectAudioFormats(_ lhs: [AudioFormatOption], _ rhs: [AudioFormatOption]) -> [AudioFormatOption] {
        ContentViewModelSupport.intersectAudioFormats(lhs, rhs)
    }

    // MARK: - Conversion Control

    func startConversion() {
        launchConversionTask(&conversionTask, isRunning: isConverting) { [weak self] in
            await self?.convert()
        }
    }

    func cancelConversion() {
        cancelConversionTask(conversionTask, isRunning: isConverting)
    }

    func startImageConversion() {
        launchConversionTask(&imageConversionTask, isRunning: isImageConverting) { [weak self] in
            await self?.convertImage()
        }
    }

    func cancelImageConversion() {
        cancelConversionTask(imageConversionTask, isRunning: isImageConverting)
    }

    func startAudioConversion() {
        launchConversionTask(&audioConversionTask, isRunning: isAudioConverting) { [weak self] in
            await self?.convertAudio()
        }
    }

    func cancelAudioConversion() {
        cancelConversionTask(audioConversionTask, isRunning: isAudioConverting)
    }

    private func launchConversionTask(
        _ task: inout Task<Void, Never>?,
        isRunning: Bool,
        operation: @escaping @MainActor () async -> Void
    ) {
        guard !isRunning else { return }
        task = Task {
            await operation()
        }
    }

    private func cancelConversionTask(_ task: Task<Void, Never>?, isRunning: Bool) {
        guard isRunning else { return }
        task?.cancel()
    }

    private struct AggregatedSourceCapabilities<Format> {
        var commonFormats: [Format] = []
        var warnings: [String] = []
        var errors: [String] = []
    }

    private func aggregateSourceCapabilities<Capability, Format>(
        for selection: [URL],
        fetchCapabilities: @escaping (URL) async -> Capability,
        availableFormats: (Capability) -> [Format],
        warningMessage: (Capability) -> String?,
        errorMessage: (Capability) -> String?,
        intersect: ([Format], [Format]) -> [Format],
        onCapability: ((URL, Capability) -> Void)? = nil
    ) async -> AggregatedSourceCapabilities<Format>? {
        var isInitialized = false
        var aggregated = AggregatedSourceCapabilities<Format>()

        for source in selection {
            guard !Task.isCancelled else { return nil }

            let shouldStopSourceAccessing = source.startAccessingSecurityScopedResource()
            defer {
                if shouldStopSourceAccessing {
                    source.stopAccessingSecurityScopedResource()
                }
            }

            let capabilities = await fetchCapabilities(source)
            onCapability?(source, capabilities)

            let formats = availableFormats(capabilities)
            if isInitialized {
                aggregated.commonFormats = intersect(aggregated.commonFormats, formats)
            } else {
                aggregated.commonFormats = formats
                isInitialized = true
            }

            if let warning = warningMessage(capabilities) {
                aggregated.warnings.append(labeledCapabilityMessage(warning, for: source, totalCount: selection.count))
            }
            if let error = errorMessage(capabilities) {
                aggregated.errors.append(labeledCapabilityMessage(error, for: source, totalCount: selection.count))
            }
        }

        guard !Task.isCancelled else { return nil }
        return aggregated
    }

    // MARK: - Video Source / Analyze

    private func applySelectedVideoSources(_ urls: [URL]) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let firstURL = uniqueURLs.first else { return }

        cancelTask(&sourceAnalysisTask)

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

        analyzeSourceCompatibility(for: uniqueURLs)
    }

    private func analyzeSourceCompatibility(for urls: [URL]) {
        let selection = uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(sourceIdentifier(for:))
        guard !selection.isEmpty else {
            isAnalyzingSource = false
            availableOutputFormats = []
            sourceCompatibilityErrorMessage = nil
            sourceCompatibilityWarningMessage = nil
            return
        }

        isAnalyzingSource = true

        sourceAnalysisTask = Task { [weak self] in
            guard let self else { return }
            guard let aggregated = await self.aggregateSourceCapabilities(
                for: selection,
                fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                warningMessage: { $0.warningMessage },
                errorMessage: { $0.errorMessage },
                intersect: { self.intersectVideoFormats($0, $1) }
            ) else {
                return
            }
            guard self.selectedVideoSourceURLs.map({ self.sourceIdentifier(for: $0) }) == expectedSourceIDs else { return }

            let resolvedFormats = VideoFormatOption.deduplicatedAndSorted(aggregated.commonFormats)
            self.isAnalyzingSource = false
            self.availableOutputFormats = resolvedFormats
            self.sourceCompatibilityWarningMessage = self.joinedCapabilityMessages(aggregated.warnings)

            if let joinedErrors = self.joinedCapabilityMessages(aggregated.errors) {
                self.sourceCompatibilityErrorMessage = joinedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                self.sourceCompatibilityErrorMessage = "No common output container is available for the selected files."
            } else {
                self.sourceCompatibilityErrorMessage = nil
            }

            if let first = resolvedFormats.first,
               !resolvedFormats.contains(where: { $0.normalizedID == self.selectedOutputFormat.normalizedID }) {
                self.selectedOutputFormat = first
            }

            self.ensureSelectedVideoOutputFormatIsAvailable()
            self.refreshVideoCodecOptions()
            self.persistCurrentSettingsIfNeeded()
        }
    }

    // MARK: - Image Source / Analyze

    private func applySelectedImageSources(_ urls: [URL]) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let firstURL = uniqueURLs.first else { return }

        cancelTask(&imageSourceAnalysisTask)

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

        analyzeImageSourceCompatibility(for: uniqueURLs)
    }

    private func analyzeImageSourceCompatibility(for urls: [URL]) {
        let selection = uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(sourceIdentifier(for:))
        guard !selection.isEmpty else {
            isAnalyzingImageSource = false
            availableImageOutputFormats = []
            imageSourceFrameCount = 0
            imageSourceHasAlpha = false
            imageSourceCompatibilityErrorMessage = nil
            imageSourceCompatibilityWarningMessage = nil
            return
        }

        isAnalyzingImageSource = true

        imageSourceAnalysisTask = Task { [weak self] in
            guard let self else { return }

            let primarySourceID = expectedSourceIDs.first
            var primaryFrameCount = 0
            var primaryHasAlpha = false
            guard let aggregated = await self.aggregateSourceCapabilities(
                for: selection,
                fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                warningMessage: { $0.warningMessage },
                errorMessage: { $0.errorMessage },
                intersect: { self.intersectImageFormats($0, $1) },
                onCapability: { source, capabilities in
                    let sourceID = self.sourceIdentifier(for: source)
                    if sourceID == primarySourceID {
                        primaryFrameCount = capabilities.frameCount
                        primaryHasAlpha = capabilities.hasAlpha
                    }
                }
            ) else {
                return
            }
            guard self.selectedImageSourceURLs.map({ self.sourceIdentifier(for: $0) }) == expectedSourceIDs else { return }

            let resolvedFormats = ImageFormatOption.deduplicatedAndSorted(aggregated.commonFormats)
            self.isAnalyzingImageSource = false
            self.availableImageOutputFormats = resolvedFormats
            self.imageSourceCompatibilityWarningMessage = self.joinedCapabilityMessages(aggregated.warnings)
            self.imageSourceFrameCount = primaryFrameCount
            self.imageSourceHasAlpha = primaryHasAlpha

            if let joinedErrors = self.joinedCapabilityMessages(aggregated.errors) {
                self.imageSourceCompatibilityErrorMessage = joinedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                self.imageSourceCompatibilityErrorMessage = "No common output format is available for the selected files."
            } else {
                self.imageSourceCompatibilityErrorMessage = nil
            }

            if let first = resolvedFormats.first,
               !resolvedFormats.contains(where: { $0.normalizedID == self.selectedImageOutputFormat.normalizedID }) {
                self.selectedImageOutputFormat = first
            }

            self.ensureSelectedImageOutputFormatIsAvailable()
            self.persistCurrentImageSettingsIfNeeded()
        }
    }

    // MARK: - Audio Source / Analyze

    private func applySelectedAudioSources(_ urls: [URL]) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let firstURL = uniqueURLs.first else { return }

        cancelTask(&audioSourceAnalysisTask)

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

        analyzeAudioSourceCompatibility(for: uniqueURLs)
    }

    private func analyzeAudioSourceCompatibility(for urls: [URL]) {
        let selection = uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(sourceIdentifier(for:))
        guard !selection.isEmpty else {
            isAnalyzingAudioSource = false
            availableAudioOutputFormats = []
            audioSourceCompatibilityErrorMessage = nil
            audioSourceCompatibilityWarningMessage = nil
            return
        }

        isAnalyzingAudioSource = true

        audioSourceAnalysisTask = Task { [weak self] in
            guard let self else { return }
            guard let aggregated = await self.aggregateSourceCapabilities(
                for: selection,
                fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                warningMessage: { $0.warningMessage },
                errorMessage: { $0.errorMessage },
                intersect: { self.intersectAudioFormats($0, $1) }
            ) else {
                return
            }
            guard self.selectedAudioSourceURLs.map({ self.sourceIdentifier(for: $0) }) == expectedSourceIDs else { return }

            let resolvedFormats = AudioFormatOption.deduplicatedAndSorted(aggregated.commonFormats)
            self.isAnalyzingAudioSource = false
            self.availableAudioOutputFormats = resolvedFormats
            self.audioSourceCompatibilityWarningMessage = self.joinedCapabilityMessages(aggregated.warnings)

            if let joinedErrors = self.joinedCapabilityMessages(aggregated.errors) {
                self.audioSourceCompatibilityErrorMessage = joinedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                self.audioSourceCompatibilityErrorMessage = "No common audio output format is available for the selected files."
            } else {
                self.audioSourceCompatibilityErrorMessage = nil
            }

            if let first = resolvedFormats.first,
               !resolvedFormats.contains(where: { $0.normalizedID == self.selectedAudioOutputFormat.normalizedID }) {
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

    private func removeProcessedVideoSource(_ processedURL: URL) {
        let processedID = sourceIdentifier(for: processedURL)
        let remainingSources = selectedVideoSourceURLs.filter { sourceIdentifier(for: $0) != processedID }

        sourceURL = remainingSources.first
        queuedSourceURLs = Array(remainingSources.dropFirst())

        guard sourceURL == nil else { return }

        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil
        isAnalyzingSource = false
        availableOutputFormats = VideoConversionEngine.defaultOutputFormats()
        ensureSelectedVideoOutputFormatIsAvailable()
        refreshVideoCodecOptions()
    }

    private func removeProcessedImageSource(_ processedURL: URL) {
        let processedID = sourceIdentifier(for: processedURL)
        let remainingSources = selectedImageSourceURLs.filter { sourceIdentifier(for: $0) != processedID }

        imageSourceURL = remainingSources.first
        queuedImageSourceURLs = Array(remainingSources.dropFirst())

        guard imageSourceURL == nil else { return }

        imageSourceFrameCount = 0
        imageSourceHasAlpha = false
        imageSourceCompatibilityErrorMessage = nil
        imageSourceCompatibilityWarningMessage = nil
        isAnalyzingImageSource = false
        availableImageOutputFormats = ImageConversionEngine.defaultOutputFormats()
        ensureSelectedImageOutputFormatIsAvailable()
    }

    private func removeProcessedAudioSource(_ processedURL: URL) {
        let processedID = sourceIdentifier(for: processedURL)
        let remainingSources = selectedAudioSourceURLs.filter { sourceIdentifier(for: $0) != processedID }

        audioSourceURL = remainingSources.first
        queuedAudioSourceURLs = Array(remainingSources.dropFirst())

        guard audioSourceURL == nil else { return }

        audioSourceCompatibilityErrorMessage = nil
        audioSourceCompatibilityWarningMessage = nil
        isAnalyzingAudioSource = false
        availableAudioOutputFormats = VideoConversionEngine.defaultAudioOutputFormats()
        ensureSelectedAudioOutputFormatIsAvailable()
        refreshAudioCodecOptions()
    }

    private func validateVideoOutputSettings(for sourceURL: URL) async -> String? {
        if requiresFFmpegForCurrentVideoSettings && !VideoConversionEngine.isFFmpegAvailable() {
            return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
        }

        let capabilities = await VideoConversionEngine.sourceCapabilities(for: sourceURL)
        if let error = capabilities.errorMessage {
            return error
        }

        let isFormatAvailable = capabilities.availableOutputFormats.contains {
            $0.normalizedID == selectedOutputFormat.normalizedID
        }
        if !isFormatAvailable {
            return "Selected container is not available for this source."
        }

        return nil
    }

    private func validateImageOutputSettings(for sourceURL: URL) async -> String? {
        let capabilities = await ImageConversionEngine.sourceCapabilities(for: sourceURL)
        if let error = capabilities.errorMessage {
            return error
        }

        let isFormatAvailable = capabilities.availableOutputFormats.contains {
            $0.normalizedID == selectedImageOutputFormat.normalizedID
        }
        if !isFormatAvailable {
            return "Selected output format is not available for this source."
        }

        if capabilities.frameCount > 1 &&
            preserveImageAnimation &&
            selectedImageOutputFormat.supportsAnimation &&
            !ImageConversionEngine.isFFmpegAvailable() {
            return "Animated output requires ffmpeg for the selected format."
        }

        return nil
    }

    private func validateAudioOutputSettings(for sourceURL: URL) async -> String? {
        let capabilities = await VideoConversionEngine.sourceCapabilitiesForAudio(for: sourceURL)
        if let error = capabilities.errorMessage {
            return error
        }

        let isFormatAvailable = capabilities.availableOutputFormats.contains {
            $0.normalizedID == selectedAudioOutputFormat.normalizedID
        }
        if !isFormatAvailable {
            return "Selected output format is not available for this source."
        }

        return nil
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

        guard let batchContext = BatchConversionSupport.prepareContext(
            sourceURLs: [sourceURL] + queuedSourceURLs,
            fileExtension: selectedOutputFormat.fileExtension,
            outputLabel: "Video"
        ) else {
            return
        }
        let sourceURLs = batchContext.sourceURLs
        let destinationURLsBySourceID = batchContext.destinationURLsBySourceID
        defer { batchContext.stopAccessingBatchDirectory() }

        prepareConversionStartState()
        totalVideoBatchCount = sourceURLs.count
        currentVideoBatchIndex = 0

        do {
            defer {
                isConverting = false
                currentVideoBatchIndex = 0
                totalVideoBatchCount = 0
            }
            try Task.checkCancellation()

            var skippedEntries: [String] = []

            for (index, currentSourceURL) in sourceURLs.enumerated() {
                try Task.checkCancellation()
                currentVideoBatchIndex = index + 1

                let shouldStopSourceAccessing = currentSourceURL.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopSourceAccessing {
                        currentSourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                if let validationMessage = await validateVideoOutputSettings(for: currentSourceURL) {
                    skippedEntries.append("\(currentSourceURL.lastPathComponent): \(validationMessage)")
                    removeProcessedVideoSource(currentSourceURL)
                    continue
                }

                let destinationURL = try BatchConversionSupport.destinationURL(
                    for: currentSourceURL,
                    in: destinationURLsBySourceID,
                    errorCode: -1001
                )

                let workingOutputURL = VideoConversionEngine.temporaryOutputURL(
                    for: currentSourceURL,
                    format: selectedOutputFormat
                )
                defer { BatchConversionSupport.cleanupWorkingOutputIfNeeded(workingOutputURL) }

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

                let savedURL = try BatchConversionSupport.saveConvertedOutput(from: output, to: destinationURL)
                convertedURL = savedURL
                convertedURLs.append(savedURL)
                removeProcessedVideoSource(currentSourceURL)
            }

            conversionProgress = 1
            if let summary = BatchConversionSupport.skippedFilesSummary(
                prefix: "Some video files were skipped:",
                entries: skippedEntries
            ) {
                conversionErrorMessage = summary
            }
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
        guard let batchContext = BatchConversionSupport.prepareContext(
            sourceURLs: [sourceURL] + queuedImageSourceURLs,
            fileExtension: selectedImageOutputFormat.fileExtension,
            outputLabel: "Image"
        ) else {
            return
        }
        let sourceURLs = batchContext.sourceURLs
        let destinationURLsBySourceID = batchContext.destinationURLsBySourceID
        defer { batchContext.stopAccessingBatchDirectory() }

        prepareImageConversionStartState()
        totalImageBatchCount = sourceURLs.count
        currentImageBatchIndex = 0

        do {
            defer {
                isImageConverting = false
                currentImageBatchIndex = 0
                totalImageBatchCount = 0
            }
            try Task.checkCancellation()

            var skippedEntries: [String] = []

            for (index, currentSourceURL) in sourceURLs.enumerated() {
                try Task.checkCancellation()
                currentImageBatchIndex = index + 1

                let shouldStopSourceAccessing = currentSourceURL.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopSourceAccessing {
                        currentSourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                if let validationMessage = await validateImageOutputSettings(for: currentSourceURL) {
                    skippedEntries.append("\(currentSourceURL.lastPathComponent): \(validationMessage)")
                    removeProcessedImageSource(currentSourceURL)
                    continue
                }

                let destinationURL = try BatchConversionSupport.destinationURL(
                    for: currentSourceURL,
                    in: destinationURLsBySourceID,
                    errorCode: -1002
                )

                let workingOutputURL = ImageConversionEngine.temporaryOutputURL(
                    for: currentSourceURL,
                    format: selectedImageOutputFormat
                )
                defer { BatchConversionSupport.cleanupWorkingOutputIfNeeded(workingOutputURL) }

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

                let savedURL = try BatchConversionSupport.saveConvertedOutput(from: output, to: destinationURL)
                convertedImageURL = savedURL
                convertedImageURLs.append(savedURL)
                removeProcessedImageSource(currentSourceURL)
            }

            imageConversionProgress = 1
            if let summary = BatchConversionSupport.skippedFilesSummary(
                prefix: "Some image files were skipped:",
                entries: skippedEntries
            ) {
                imageConversionErrorMessage = summary
            }
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
        guard let batchContext = BatchConversionSupport.prepareContext(
            sourceURLs: [sourceURL] + queuedAudioSourceURLs,
            fileExtension: selectedAudioOutputFormat.fileExtension,
            outputLabel: "Audio"
        ) else {
            return
        }
        let sourceURLs = batchContext.sourceURLs
        let destinationURLsBySourceID = batchContext.destinationURLsBySourceID
        defer { batchContext.stopAccessingBatchDirectory() }

        prepareAudioConversionStartState()
        totalAudioBatchCount = sourceURLs.count
        currentAudioBatchIndex = 0

        do {
            defer {
                isAudioConverting = false
                currentAudioBatchIndex = 0
                totalAudioBatchCount = 0
            }
            try Task.checkCancellation()

            var skippedEntries: [String] = []

            for (index, currentSourceURL) in sourceURLs.enumerated() {
                try Task.checkCancellation()
                currentAudioBatchIndex = index + 1

                let shouldStopSourceAccessing = currentSourceURL.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopSourceAccessing {
                        currentSourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                if let validationMessage = await validateAudioOutputSettings(for: currentSourceURL) {
                    skippedEntries.append("\(currentSourceURL.lastPathComponent): \(validationMessage)")
                    removeProcessedAudioSource(currentSourceURL)
                    continue
                }

                let destinationURL = try BatchConversionSupport.destinationURL(
                    for: currentSourceURL,
                    in: destinationURLsBySourceID,
                    errorCode: -1003
                )

                let workingOutputURL = VideoConversionEngine.temporaryOutputURL(
                    for: currentSourceURL,
                    format: selectedAudioOutputFormat
                )
                defer { BatchConversionSupport.cleanupWorkingOutputIfNeeded(workingOutputURL) }

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

                let savedURL = try BatchConversionSupport.saveConvertedOutput(from: output, to: destinationURL)
                convertedAudioURL = savedURL
                convertedAudioURLs.append(savedURL)
                removeProcessedAudioSource(currentSourceURL)
            }

            audioConversionProgress = 1
            if let summary = BatchConversionSupport.skippedFilesSummary(
                prefix: "Some audio files were skipped:",
                entries: skippedEntries
            ) {
                audioConversionErrorMessage = summary
            }
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
        ContentViewModelSupport.clampedProgress(rawProgress)
    }

    private func sourceIdentifier(for url: URL) -> String {
        ContentViewModelSupport.sourceIdentifier(for: url)
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

        if let preferredVideo = ContentViewModelSupport.preferredVideoEncoder(from: availableVideoEncoders),
           !availableVideoEncoders.contains(selectedVideoEncoder) {
            selectedVideoEncoder = preferredVideo
        }
        if format.supportsAudioTrack,
           let preferredAudio = ContentViewModelSupport.preferredAudioEncoder(from: availableAudioEncoders),
           !availableAudioEncoders.contains(selectedAudioEncoder) {
            selectedAudioEncoder = preferredAudio
        }

        normalizeVideoOptionDependencies()
    }

    private func refreshAudioCodecOptions() {
        let format = selectedAudioOutputFormat
        availableAudioOutputEncoders = VideoConversionEngine.availableAudioEncoders(for: format)

        let effectiveOptions: [AudioEncoderOption]
        if !availableAudioOutputEncoders.isEmpty {
            effectiveOptions = availableAudioOutputEncoders
        } else if audioSourceURL == nil && format.allowsFFmpegAutomaticAudioCodec {
            effectiveOptions = [.auto]
        } else {
            effectiveOptions = []
        }

        if let preferred = ContentViewModelSupport.preferredAudioOutputEncoder(for: format, from: effectiveOptions),
           !effectiveOptions.contains(selectedAudioOutputEncoder) {
            selectedAudioOutputEncoder = preferred
        }

        normalizeAudioOptionDependencies()
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
           let preferred = ContentViewModelSupport.preferredAudioOutputEncoder(
               for: selectedAudioOutputFormat,
               from: options
           ) {
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

}
