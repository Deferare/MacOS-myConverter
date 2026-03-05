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

    private func assignPrimaryAndQueuedSources(
        _ urls: [URL],
        primaryKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        queuedKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>
    ) {
        self[keyPath: primaryKeyPath] = urls.first
        self[keyPath: queuedKeyPath] = Array(urls.dropFirst())
    }

    private func applySelectedSources(
        _ urls: [URL],
        cancelAnalysisTask: () -> Void,
        assignSelection: ([URL]) -> Void,
        resetState: () -> Void,
        applyStoredSettingsForSourceID: (String) -> Void,
        analyzeSelection: ([URL]) -> Void
    ) {
        let uniqueURLs = uniqueStandardizedURLs(urls)
        guard let firstURL = uniqueURLs.first else { return }

        cancelAnalysisTask()
        assignSelection(uniqueURLs)
        resetState()

        let sourceID = sourceIdentifier(for: firstURL)
        applyStoredSettingsForSourceID(sourceID)
        analyzeSelection(uniqueURLs)
    }

    private func moveSelectedSource(
        from draggedURL: URL,
        to targetURL: URL,
        isConversionRunning: Bool,
        currentPrimaryURL: URL?,
        selectedSourceURLs: [URL],
        assignSelection: ([URL]) -> Void,
        cancelAnalysisTask: () -> Void,
        resetCompatibilityState: () -> Void,
        applyStoredSettingsForSourceID: (String) -> Void,
        analyzeSelection: ([URL]) -> Void
    ) {
        guard !isConversionRunning else { return }
        let previousPrimaryID = currentPrimaryURL.map(sourceIdentifier(for:))
        guard let reordered = reorderedURLsByMoving(draggedURL, to: targetURL, in: selectedSourceURLs) else {
            return
        }

        assignSelection(reordered)

        guard let newPrimarySourceURL = reordered.first else { return }
        guard sourceIdentifier(for: newPrimarySourceURL) != previousPrimaryID else { return }

        cancelAnalysisTask()
        resetCompatibilityState()

        let sourceID = sourceIdentifier(for: newPrimarySourceURL)
        applyStoredSettingsForSourceID(sourceID)
        analyzeSelection(reordered)
    }

    private func applyStoredSettingsForSource<Settings>(
        sourceID: String,
        settingsBySourceID: [String: Settings],
        defaultSettings: @autoclosure () -> Settings,
        apply: (Settings) -> Void
    ) {
        let stored = settingsBySourceID[sourceID] ?? defaultSettings()
        apply(stored)
    }

    private func removeProcessedSource(
        _ processedURL: URL,
        from selectedSourceURLs: [URL],
        assignSelection: ([URL]) -> Void,
        onSelectionEmptied: () -> Void
    ) {
        let processedID = sourceIdentifier(for: processedURL)
        let remainingSources = selectedSourceURLs.filter { sourceIdentifier(for: $0) != processedID }
        assignSelection(remainingSources)
        guard !remainingSources.isEmpty else {
            onSelectionEmptied()
            return
        }
    }

    private func clearSelectedSourceState(
        cancelAnalysisTask: () -> Void,
        resetSelectionAndOutput: () -> Void,
        resetCompatibilityAndBatchState: () -> Void,
        resetFormatsAndSettings: () -> Void
    ) {
        cancelAnalysisTask()
        resetSelectionAndOutput()
        resetCompatibilityAndBatchState()
        resetFormatsAndSettings()
    }

    private func applyImportedSources(
        _ urls: [URL],
        accept: (URL) -> Bool,
        applySelection: ([URL]) -> Void
    ) {
        let filtered = urls.filter(accept)
        guard !filtered.isEmpty else { return }
        applySelection(filtered)
    }

    private func assignVideoSelection(_ urls: [URL]) {
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: \.sourceURL,
            queuedKeyPath: \.queuedSourceURLs
        )
    }

    private func assignImageSelection(_ urls: [URL]) {
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: \.imageSourceURL,
            queuedKeyPath: \.queuedImageSourceURLs
        )
    }

    private func assignAudioSelection(_ urls: [URL]) {
        assignPrimaryAndQueuedSources(
            urls,
            primaryKeyPath: \.audioSourceURL,
            queuedKeyPath: \.queuedAudioSourceURLs
        )
    }

    private func applyStoredVideoSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: videoSettingsBySourceID,
            defaultSettings: VideoConversionSettings(),
            apply: applyStoredSettings(_:)
        )
    }

    private func applyStoredImageSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: imageSettingsBySourceID,
            defaultSettings: ImageConversionSettings(),
            apply: applyStoredImageSettings(_:)
        )
    }

    private func applyStoredAudioSettings(for sourceID: String) {
        applyStoredSettingsForSource(
            sourceID: sourceID,
            settingsBySourceID: audioSettingsBySourceID,
            defaultSettings: AudioConversionSettings(),
            apply: applyStoredAudioSettings(_:)
        )
    }

    private func resetVideoConversionOutputs() {
        convertedURL = nil
        convertedURLs = []
        conversionErrorMessage = nil
    }

    private func resetImageConversionOutputs() {
        convertedImageURL = nil
        convertedImageURLs = []
        imageConversionErrorMessage = nil
    }

    private func resetAudioConversionOutputs() {
        convertedAudioURL = nil
        convertedAudioURLs = []
        audioConversionErrorMessage = nil
    }

    private func resetVideoCompatibilityMessages() {
        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil
    }

    private func resetImageCompatibilityState(resetMetadata: Bool) {
        if resetMetadata {
            imageSourceFrameCount = 0
            imageSourceHasAlpha = false
        }
        imageSourceCompatibilityErrorMessage = nil
        imageSourceCompatibilityWarningMessage = nil
    }

    private func resetAudioCompatibilityMessages() {
        audioSourceCompatibilityErrorMessage = nil
        audioSourceCompatibilityWarningMessage = nil
    }

    func clearSelectedSource() {
        clearSelectedVideoSource()
    }

    func clearSelectedVideoSource() {
        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(&sourceAnalysisTask)
            },
            resetSelectionAndOutput: {
                sourceURL = nil
                queuedSourceURLs = []
                resetVideoConversionOutputs()
            },
            resetCompatibilityAndBatchState: {
                resetVideoCompatibilityMessages()
                isAnalyzingSource = false
                currentVideoBatchIndex = 0
                totalVideoBatchCount = 0
            },
            resetFormatsAndSettings: {
                availableOutputFormats = VideoConversionEngine.defaultOutputFormats()
                applyStoredSettings(.init())
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    func clearSelectedImageSource() {
        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(&imageSourceAnalysisTask)
            },
            resetSelectionAndOutput: {
                imageSourceURL = nil
                queuedImageSourceURLs = []
                resetImageConversionOutputs()
            },
            resetCompatibilityAndBatchState: {
                resetImageCompatibilityState(resetMetadata: true)
                isAnalyzingImageSource = false
                currentImageBatchIndex = 0
                totalImageBatchCount = 0
            },
            resetFormatsAndSettings: {
                availableImageOutputFormats = ImageConversionEngine.defaultOutputFormats()
                applyStoredImageSettings(.init())
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    func clearSelectedAudioSource() {
        clearSelectedSourceState(
            cancelAnalysisTask: {
                cancelTask(&audioSourceAnalysisTask)
            },
            resetSelectionAndOutput: {
                audioSourceURL = nil
                queuedAudioSourceURLs = []
                resetAudioConversionOutputs()
            },
            resetCompatibilityAndBatchState: {
                resetAudioCompatibilityMessages()
                isAnalyzingAudioSource = false
                currentAudioBatchIndex = 0
                totalAudioBatchCount = 0
            },
            resetFormatsAndSettings: {
                availableAudioOutputFormats = VideoConversionEngine.defaultAudioOutputFormats()
                applyStoredAudioSettings(.init())
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }

    func handleFileImportResult(_ result: Result<[URL], Error>, for selectedTab: ConverterTab) {
        switch result {
        case .success(let urls):
            let selected = uniqueStandardizedURLs(urls)
            guard !selected.isEmpty else { return }
            switch selectedTab {
            case .video:
                applyImportedSources(selected, accept: isVideoInputURL, applySelection: applySelectedVideoSources(_:))
            case .image:
                applyImportedSources(selected, accept: isImageInputURL, applySelection: applySelectedImageSources(_:))
            case .audio:
                applyImportedSources(selected, accept: isAudioInputURL, applySelection: applySelectedAudioSources(_:))
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

    private func handleMediaDrop(
        providers: [NSItemProvider],
        accept: @escaping (URL) -> Bool,
        applySelection: @escaping @MainActor ([URL]) -> Void
    ) -> Bool {
        handleDroppedFiles(providers: providers, accept: accept, onResolvedURLs: applySelection)
    }

    func handleVideoDrop(providers: [NSItemProvider]) -> Bool {
        handleMediaDrop(providers: providers, accept: isVideoInputURL) { [weak self] urls in
            self?.applySelectedVideoSources(urls)
        }
    }

    func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        handleMediaDrop(providers: providers, accept: isImageInputURL) { [weak self] urls in
            self?.applySelectedImageSources(urls)
        }
    }

    func handleAudioDrop(providers: [NSItemProvider]) -> Bool {
        handleMediaDrop(providers: providers, accept: isAudioInputURL) { [weak self] urls in
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
        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: isConverting,
            currentPrimaryURL: sourceURL,
            selectedSourceURLs: selectedVideoSourceURLs,
            assignSelection: { reordered in
                assignVideoSelection(reordered)
            },
            cancelAnalysisTask: {
                cancelTask(&sourceAnalysisTask)
            },
            resetCompatibilityState: {
                resetVideoCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredVideoSettings(for: sourceID)
            },
            analyzeSelection: { urls in
                analyzeSourceCompatibility(for: urls)
            }
        )
    }

    func moveSelectedImageSource(from draggedURL: URL, to targetURL: URL) {
        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: isImageConverting,
            currentPrimaryURL: imageSourceURL,
            selectedSourceURLs: selectedImageSourceURLs,
            assignSelection: { reordered in
                assignImageSelection(reordered)
            },
            cancelAnalysisTask: {
                cancelTask(&imageSourceAnalysisTask)
            },
            resetCompatibilityState: {
                resetImageCompatibilityState(resetMetadata: true)
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredImageSettings(for: sourceID)
            },
            analyzeSelection: { urls in
                analyzeImageSourceCompatibility(for: urls)
            }
        )
    }

    func moveSelectedAudioSource(from draggedURL: URL, to targetURL: URL) {
        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: isAudioConverting,
            currentPrimaryURL: audioSourceURL,
            selectedSourceURLs: selectedAudioSourceURLs,
            assignSelection: { reordered in
                assignAudioSelection(reordered)
            },
            cancelAnalysisTask: {
                cancelTask(&audioSourceAnalysisTask)
            },
            resetCompatibilityState: {
                resetAudioCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredAudioSettings(for: sourceID)
            },
            analyzeSelection: { urls in
                analyzeAudioSourceCompatibility(for: urls)
            }
        )
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

    private func analyzeSourceSelection<Capability, Format>(
        urls: [URL],
        analysisTaskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        isAnalyzingKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        warningMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        selectedSourceIDs: @escaping () -> [String],
        resetForEmptySelection: () -> Void,
        fetchCapabilities: @escaping (URL) async -> Capability,
        availableFormats: @escaping (Capability) -> [Format],
        warningMessage: @escaping (Capability) -> String?,
        errorMessage: @escaping (Capability) -> String?,
        intersect: @escaping ([Format], [Format]) -> [Format],
        deduplicatedAndSorted: @escaping ([Format]) -> [Format],
        noCommonFormatsMessage: String,
        onCapability: ((URL, Capability) -> Void)? = nil,
        onFormatsResolved: @escaping ([Format]) -> Void
    ) {
        let selection = uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(sourceIdentifier(for:))
        guard !selection.isEmpty else {
            resetForEmptySelection()
            return
        }

        self[keyPath: isAnalyzingKeyPath] = true
        self[keyPath: analysisTaskKeyPath] = Task { [weak self] in
            guard let self else { return }
            guard let aggregated = await self.aggregateSourceCapabilities(
                for: selection,
                fetchCapabilities: fetchCapabilities,
                availableFormats: availableFormats,
                warningMessage: warningMessage,
                errorMessage: errorMessage,
                intersect: intersect,
                onCapability: onCapability
            ) else {
                return
            }
            guard selectedSourceIDs() == expectedSourceIDs else { return }

            let resolvedFormats = deduplicatedAndSorted(aggregated.commonFormats)
            self[keyPath: isAnalyzingKeyPath] = false
            self[keyPath: availableFormatsKeyPath] = resolvedFormats
            self[keyPath: warningMessageKeyPath] = self.joinedCapabilityMessages(aggregated.warnings)

            if let joinedErrors = self.joinedCapabilityMessages(aggregated.errors) {
                self[keyPath: errorMessageKeyPath] = joinedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                self[keyPath: errorMessageKeyPath] = noCommonFormatsMessage
            } else {
                self[keyPath: errorMessageKeyPath] = nil
            }

            onFormatsResolved(resolvedFormats)
        }
    }

    // MARK: - Video Source / Analyze

    private func applySelectedVideoSources(_ urls: [URL]) {
        applySelectedSources(
            urls,
            cancelAnalysisTask: {
                cancelTask(&sourceAnalysisTask)
            },
            assignSelection: { selection in
                assignVideoSelection(selection)
            },
            resetState: {
                resetVideoConversionOutputs()
                resetVideoCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredVideoSettings(for: sourceID)
            },
            analyzeSelection: { selection in
                analyzeSourceCompatibility(for: selection)
            }
        )
    }

    private func analyzeSourceCompatibility(for urls: [URL]) {
        analyzeSourceSelection(
            urls: urls,
            analysisTaskKeyPath: \.sourceAnalysisTask,
            isAnalyzingKeyPath: \.isAnalyzingSource,
            availableFormatsKeyPath: \.availableOutputFormats,
            warningMessageKeyPath: \.sourceCompatibilityWarningMessage,
            errorMessageKeyPath: \.sourceCompatibilityErrorMessage,
            selectedSourceIDs: {
                self.selectedVideoSourceURLs.map { self.sourceIdentifier(for: $0) }
            },
            resetForEmptySelection: {
                isAnalyzingSource = false
                availableOutputFormats = []
                sourceCompatibilityErrorMessage = nil
                sourceCompatibilityWarningMessage = nil
            },
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            intersect: { lhs, rhs in
                ContentViewModelSupport.intersectFormats(lhs, rhs, normalizedID: { $0.normalizedID })
            },
            deduplicatedAndSorted: { VideoFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output container is available for the selected files.",
            onFormatsResolved: { resolvedFormats in
                if let first = resolvedFormats.first,
                   !resolvedFormats.contains(where: { $0.normalizedID == self.selectedOutputFormat.normalizedID }) {
                    self.selectedOutputFormat = first
                }

                self.ensureSelectedVideoOutputFormatIsAvailable()
                self.refreshVideoCodecOptions()
                self.persistCurrentSettingsIfNeeded()
            }
        )
    }

    // MARK: - Image Source / Analyze

    private func applySelectedImageSources(_ urls: [URL]) {
        applySelectedSources(
            urls,
            cancelAnalysisTask: {
                cancelTask(&imageSourceAnalysisTask)
            },
            assignSelection: { selection in
                assignImageSelection(selection)
            },
            resetState: {
                resetImageCompatibilityState(resetMetadata: true)
                resetImageConversionOutputs()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredImageSettings(for: sourceID)
            },
            analyzeSelection: { selection in
                analyzeImageSourceCompatibility(for: selection)
            }
        )
    }

    private func analyzeImageSourceCompatibility(for urls: [URL]) {
        let primarySourceID = uniqueStandardizedURLs(urls).first.map(sourceIdentifier(for:))
        var primaryFrameCount = 0
        var primaryHasAlpha = false

        analyzeSourceSelection(
            urls: urls,
            analysisTaskKeyPath: \.imageSourceAnalysisTask,
            isAnalyzingKeyPath: \.isAnalyzingImageSource,
            availableFormatsKeyPath: \.availableImageOutputFormats,
            warningMessageKeyPath: \.imageSourceCompatibilityWarningMessage,
            errorMessageKeyPath: \.imageSourceCompatibilityErrorMessage,
            selectedSourceIDs: {
                self.selectedImageSourceURLs.map { self.sourceIdentifier(for: $0) }
            },
            resetForEmptySelection: {
                isAnalyzingImageSource = false
                availableImageOutputFormats = []
                imageSourceFrameCount = 0
                imageSourceHasAlpha = false
                imageSourceCompatibilityErrorMessage = nil
                imageSourceCompatibilityWarningMessage = nil
            },
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            intersect: { lhs, rhs in
                ContentViewModelSupport.intersectFormats(lhs, rhs, normalizedID: { $0.normalizedID })
            },
            deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output format is available for the selected files.",
            onCapability: { source, capabilities in
                let sourceID = self.sourceIdentifier(for: source)
                if sourceID == primarySourceID {
                    primaryFrameCount = capabilities.frameCount
                    primaryHasAlpha = capabilities.hasAlpha
                }
            },
            onFormatsResolved: { resolvedFormats in
                self.imageSourceFrameCount = primaryFrameCount
                self.imageSourceHasAlpha = primaryHasAlpha

                if let first = resolvedFormats.first,
                   !resolvedFormats.contains(where: { $0.normalizedID == self.selectedImageOutputFormat.normalizedID }) {
                    self.selectedImageOutputFormat = first
                }

                self.ensureSelectedImageOutputFormatIsAvailable()
                self.persistCurrentImageSettingsIfNeeded()
            }
        )
    }

    // MARK: - Audio Source / Analyze

    private func applySelectedAudioSources(_ urls: [URL]) {
        applySelectedSources(
            urls,
            cancelAnalysisTask: {
                cancelTask(&audioSourceAnalysisTask)
            },
            assignSelection: { selection in
                assignAudioSelection(selection)
            },
            resetState: {
                resetAudioConversionOutputs()
                resetAudioCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredAudioSettings(for: sourceID)
            },
            analyzeSelection: { selection in
                analyzeAudioSourceCompatibility(for: selection)
            }
        )
    }

    private func analyzeAudioSourceCompatibility(for urls: [URL]) {
        analyzeSourceSelection(
            urls: urls,
            analysisTaskKeyPath: \.audioSourceAnalysisTask,
            isAnalyzingKeyPath: \.isAnalyzingAudioSource,
            availableFormatsKeyPath: \.availableAudioOutputFormats,
            warningMessageKeyPath: \.audioSourceCompatibilityWarningMessage,
            errorMessageKeyPath: \.audioSourceCompatibilityErrorMessage,
            selectedSourceIDs: {
                self.selectedAudioSourceURLs.map { self.sourceIdentifier(for: $0) }
            },
            resetForEmptySelection: {
                isAnalyzingAudioSource = false
                availableAudioOutputFormats = []
                audioSourceCompatibilityErrorMessage = nil
                audioSourceCompatibilityWarningMessage = nil
            },
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            intersect: { lhs, rhs in
                ContentViewModelSupport.intersectFormats(lhs, rhs, normalizedID: { $0.normalizedID })
            },
            deduplicatedAndSorted: { AudioFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common audio output format is available for the selected files.",
            onFormatsResolved: { resolvedFormats in
                if let first = resolvedFormats.first,
                   !resolvedFormats.contains(where: { $0.normalizedID == self.selectedAudioOutputFormat.normalizedID }) {
                    self.selectedAudioOutputFormat = first
                }

                self.ensureSelectedAudioOutputFormatIsAvailable()
                self.refreshAudioCodecOptions()
                self.persistCurrentAudioSettingsIfNeeded()
            }
        )
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

    private func prepareBatchStartState(
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        primaryOutputKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        outputsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>
    ) {
        self[keyPath: runningKeyPath] = true
        self[keyPath: primaryOutputKeyPath] = nil
        self[keyPath: outputsKeyPath] = []
        self[keyPath: errorMessageKeyPath] = nil
        self[keyPath: progressKeyPath] = 0
    }

    private func prepareConversionStartState() {
        prepareBatchStartState(
            runningKeyPath: \.isConverting,
            primaryOutputKeyPath: \.convertedURL,
            outputsKeyPath: \.convertedURLs,
            errorMessageKeyPath: \.conversionErrorMessage,
            progressKeyPath: \.conversionProgress
        )
    }

    private func prepareImageConversionStartState() {
        prepareBatchStartState(
            runningKeyPath: \.isImageConverting,
            primaryOutputKeyPath: \.convertedImageURL,
            outputsKeyPath: \.convertedImageURLs,
            errorMessageKeyPath: \.imageConversionErrorMessage,
            progressKeyPath: \.imageConversionProgress
        )
    }

    private func prepareAudioConversionStartState() {
        prepareBatchStartState(
            runningKeyPath: \.isAudioConverting,
            primaryOutputKeyPath: \.convertedAudioURL,
            outputsKeyPath: \.convertedAudioURLs,
            errorMessageKeyPath: \.audioConversionErrorMessage,
            progressKeyPath: \.audioConversionProgress
        )
    }

    private func appendConvertedOutput(
        _ outputURL: URL,
        primaryOutputKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        outputsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>
    ) {
        self[keyPath: primaryOutputKeyPath] = outputURL
        var outputs = self[keyPath: outputsKeyPath]
        outputs.append(outputURL)
        self[keyPath: outputsKeyPath] = outputs
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
        removeProcessedSource(
            processedURL,
            from: selectedVideoSourceURLs,
            assignSelection: assignVideoSelection(_:),
            onSelectionEmptied: {
                resetVideoCompatibilityMessages()
                isAnalyzingSource = false
                availableOutputFormats = VideoConversionEngine.defaultOutputFormats()
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    private func removeProcessedImageSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedImageSourceURLs,
            assignSelection: assignImageSelection(_:),
            onSelectionEmptied: {
                resetImageCompatibilityState(resetMetadata: true)
                isAnalyzingImageSource = false
                availableImageOutputFormats = ImageConversionEngine.defaultOutputFormats()
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    private func removeProcessedAudioSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedAudioSourceURLs,
            assignSelection: assignAudioSelection(_:),
            onSelectionEmptied: {
                resetAudioCompatibilityMessages()
                isAnalyzingAudioSource = false
                availableAudioOutputFormats = VideoConversionEngine.defaultAudioOutputFormats()
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }

    private func validateOutputFormatAvailability<Capability, Format>(
        for sourceURL: URL,
        selectedFormatNormalizedID: String,
        unavailableMessage: String,
        fetchCapabilities: (URL) async -> Capability,
        availableFormats: (Capability) -> [Format],
        errorMessage: (Capability) -> String?,
        formatNormalizedID: (Format) -> String,
        additionalValidation: (Capability) -> String? = { _ in nil }
    ) async -> String? {
        let capabilities = await fetchCapabilities(sourceURL)
        if let error = errorMessage(capabilities) {
            return error
        }

        let isFormatAvailable = availableFormats(capabilities).contains {
            formatNormalizedID($0) == selectedFormatNormalizedID
        }
        if !isFormatAvailable {
            return unavailableMessage
        }

        if let extraValidationMessage = additionalValidation(capabilities) {
            return extraValidationMessage
        }

        return nil
    }

    private func validateVideoOutputSettings(for sourceURL: URL) async -> String? {
        if requiresFFmpegForCurrentVideoSettings && !VideoConversionEngine.isFFmpegAvailable() {
            return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
        }

        return await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedOutputFormat.normalizedID,
            unavailableMessage: "Selected container is not available for this source.",
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID }
        )
    }

    private func validateImageOutputSettings(for sourceURL: URL) async -> String? {
        await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedImageOutputFormat.normalizedID,
            unavailableMessage: "Selected output format is not available for this source.",
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            additionalValidation: { capabilities in
                if capabilities.frameCount > 1 &&
                    preserveImageAnimation &&
                    selectedImageOutputFormat.supportsAnimation &&
                    !ImageConversionEngine.isFFmpegAvailable() {
                    return "Animated output requires ffmpeg for the selected format."
                }
                return nil
            }
        )
    }

    private func validateAudioOutputSettings(for sourceURL: URL) async -> String? {
        await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedAudioOutputFormat.normalizedID,
            unavailableMessage: "Selected output format is not available for this source.",
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID }
        )
    }

    private func withSourceSecurityScope<T>(
        for sourceURL: URL,
        operation: () async throws -> T
    ) async throws -> T {
        let shouldStopSourceAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopSourceAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation()
    }

    private func prepareBatchContext(
        primarySourceURL: URL,
        queuedSourceURLs: [URL],
        fileExtension: String,
        outputLabel: String
    ) -> PreparedBatchConversionContext? {
        BatchConversionSupport.prepareContext(
            sourceURLs: [primarySourceURL] + queuedSourceURLs,
            fileExtension: fileExtension,
            outputLabel: outputLabel
        )
    }

    private func runBatchConversionLoop(
        sourceURLs: [URL],
        destinationURLsBySourceID: [String: URL],
        destinationErrorCode: Int,
        validate: @escaping (URL) async -> String?,
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onBatchIndexChanged: @escaping (Int) -> Void
    ) async throws -> [String] {
        var skippedEntries: [String] = []
        let totalCount = max(sourceURLs.count, 1)

        for (index, currentSourceURL) in sourceURLs.enumerated() {
            try Task.checkCancellation()
            onBatchIndexChanged(index + 1)

            let shouldSkipSource = try await withSourceSecurityScope(for: currentSourceURL) {
                if let validationMessage = await validate(currentSourceURL) {
                    skippedEntries.append("\(currentSourceURL.lastPathComponent): \(validationMessage)")
                    onSourceProcessed(currentSourceURL)
                    return true
                }

                let destinationURL = try BatchConversionSupport.destinationURL(
                    for: currentSourceURL,
                    in: destinationURLsBySourceID,
                    errorCode: destinationErrorCode
                )

                let workingOutputURL = makeWorkingOutputURL(currentSourceURL)
                defer { BatchConversionSupport.cleanupWorkingOutputIfNeeded(workingOutputURL) }

                let output = try await runConversion(
                    currentSourceURL,
                    workingOutputURL,
                    index,
                    totalCount
                )
                try Task.checkCancellation()

                let savedURL = try BatchConversionSupport.saveConvertedOutput(from: output, to: destinationURL)
                onSavedOutput(savedURL)
                onSourceProcessed(currentSourceURL)
                return false
            }

            if shouldSkipSource {
                continue
            }
        }

        return skippedEntries
    }

    private func executeBatchConversion(
        sourceURLs: [URL],
        destinationURLsBySourceID: [String: URL],
        destinationErrorCode: Int,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (URL) async -> String?,
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        self[keyPath: totalBatchCountKeyPath] = sourceURLs.count
        self[keyPath: currentBatchIndexKeyPath] = 0

        do {
            defer {
                self[keyPath: runningKeyPath] = false
                self[keyPath: currentBatchIndexKeyPath] = 0
                self[keyPath: totalBatchCountKeyPath] = 0
            }
            try Task.checkCancellation()

            let skippedEntries = try await runBatchConversionLoop(
                sourceURLs: sourceURLs,
                destinationURLsBySourceID: destinationURLsBySourceID,
                destinationErrorCode: destinationErrorCode,
                validate: validate,
                makeWorkingOutputURL: makeWorkingOutputURL,
                runConversion: runConversion,
                onSavedOutput: onSavedOutput,
                onSourceProcessed: onSourceProcessed,
                onBatchIndexChanged: { index in
                    self[keyPath: currentBatchIndexKeyPath] = index
                }
            )

            setProgress(1, at: progressKeyPath)
            if let summary = BatchConversionSupport.skippedFilesSummary(
                prefix: skippedSummaryPrefix,
                entries: skippedEntries
            ) {
                self[keyPath: errorMessageKeyPath] = summary
            }
        } catch is CancellationError {
            setProgress(0, at: progressKeyPath)
            self[keyPath: errorMessageKeyPath] = nil
        } catch ConversionError.exportCancelled where treatExportCancellationAsCancelled {
            setProgress(0, at: progressKeyPath)
            self[keyPath: errorMessageKeyPath] = nil
        } catch {
            onError(error)
        }
    }

    private func performMediaBatchConversion<OutputSettings>(
        canConvert: Bool,
        primarySourceURL: URL?,
        queuedSourceURLs: [URL],
        missingSourceLog: String,
        fileExtension: String,
        outputLabel: String,
        destinationErrorCode: Int,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        startState: () -> Void,
        buildOutputSettings: () throws -> OutputSettings,
        validate: @escaping (URL) async -> String?,
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, OutputSettings, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        guard canConvert, let primarySourceURL else {
            if primarySourceURL == nil {
                print(missingSourceLog)
            }
            return
        }

        let outputSettings: OutputSettings
        do {
            outputSettings = try buildOutputSettings()
        } catch {
            onError(error)
            return
        }

        guard let batchContext = prepareBatchContext(
            primarySourceURL: primarySourceURL,
            queuedSourceURLs: queuedSourceURLs,
            fileExtension: fileExtension,
            outputLabel: outputLabel
        ) else {
            return
        }

        let sourceURLs = batchContext.sourceURLs
        let destinationURLsBySourceID = batchContext.destinationURLsBySourceID
        defer { batchContext.stopAccessingBatchDirectory() }

        startState()
        await executeBatchConversion(
            sourceURLs: sourceURLs,
            destinationURLsBySourceID: destinationURLsBySourceID,
            destinationErrorCode: destinationErrorCode,
            runningKeyPath: runningKeyPath,
            progressKeyPath: progressKeyPath,
            errorMessageKeyPath: errorMessageKeyPath,
            currentBatchIndexKeyPath: currentBatchIndexKeyPath,
            totalBatchCountKeyPath: totalBatchCountKeyPath,
            skippedSummaryPrefix: skippedSummaryPrefix,
            treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
            validate: validate,
            makeWorkingOutputURL: makeWorkingOutputURL,
            runConversion: { sourceURL, workingOutputURL, index, totalCount in
                try await runConversion(sourceURL, workingOutputURL, outputSettings, index, totalCount)
            },
            onSavedOutput: onSavedOutput,
            onSourceProcessed: onSourceProcessed,
            onError: onError
        )
    }

    // MARK: - Video Convert

    private func convert() async {
        defer { conversionTask = nil }

        await performMediaBatchConversion(
            canConvert: canConvert,
            primarySourceURL: sourceURL,
            queuedSourceURLs: queuedSourceURLs,
            missingSourceLog: "No file to convert.",
            fileExtension: selectedOutputFormat.fileExtension,
            outputLabel: "Video",
            destinationErrorCode: -1001,
            runningKeyPath: \.isConverting,
            progressKeyPath: \.conversionProgress,
            errorMessageKeyPath: \.conversionErrorMessage,
            currentBatchIndexKeyPath: \.currentVideoBatchIndex,
            totalBatchCountKeyPath: \.totalVideoBatchCount,
            skippedSummaryPrefix: "Some video files were skipped:",
            treatExportCancellationAsCancelled: true,
            startState: { self.prepareConversionStartState() },
            buildOutputSettings: { try self.buildVideoOutputSettings() },
            validate: { await self.validateVideoOutputSettings(for: $0) },
            makeWorkingOutputURL: { sourceURL in
                VideoConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedOutputFormat)
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await VideoConversionEngine.convert(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil
                ) { [weak self] progress in
                    guard let self else { return }
                    await self.updateConversionProgress(
                        self.normalizedBatchProgress(
                            itemProgress: progress,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            },
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(
                    savedURL,
                    primaryOutputKeyPath: \.convertedURL,
                    outputsKeyPath: \.convertedURLs
                )
            },
            onSourceProcessed: removeProcessedVideoSource(_:),
            onError: applyConversionError(_:)
        )
    }

    // MARK: - Image Convert

    private func convertImage() async {
        defer { imageConversionTask = nil }

        await performMediaBatchConversion(
            canConvert: canConvertImage,
            primarySourceURL: imageSourceURL,
            queuedSourceURLs: queuedImageSourceURLs,
            missingSourceLog: "No image file to convert.",
            fileExtension: selectedImageOutputFormat.fileExtension,
            outputLabel: "Image",
            destinationErrorCode: -1002,
            runningKeyPath: \.isImageConverting,
            progressKeyPath: \.imageConversionProgress,
            errorMessageKeyPath: \.imageConversionErrorMessage,
            currentBatchIndexKeyPath: \.currentImageBatchIndex,
            totalBatchCountKeyPath: \.totalImageBatchCount,
            skippedSummaryPrefix: "Some image files were skipped:",
            startState: { self.prepareImageConversionStartState() },
            buildOutputSettings: { self.buildImageOutputSettings() },
            validate: { await self.validateImageOutputSettings(for: $0) },
            makeWorkingOutputURL: { sourceURL in
                ImageConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedImageOutputFormat)
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await ImageConversionEngine.convert(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings
                ) { [weak self] progress in
                    guard let self else { return }
                    await self.updateImageConversionProgress(
                        self.normalizedBatchProgress(
                            itemProgress: progress,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            },
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(
                    savedURL,
                    primaryOutputKeyPath: \.convertedImageURL,
                    outputsKeyPath: \.convertedImageURLs
                )
            },
            onSourceProcessed: removeProcessedImageSource(_:),
            onError: applyImageConversionError(_:)
        )
    }

    // MARK: - Audio Convert

    private func convertAudio() async {
        defer { audioConversionTask = nil }

        await performMediaBatchConversion(
            canConvert: canConvertAudio,
            primarySourceURL: audioSourceURL,
            queuedSourceURLs: queuedAudioSourceURLs,
            missingSourceLog: "No audio file to convert.",
            fileExtension: selectedAudioOutputFormat.fileExtension,
            outputLabel: "Audio",
            destinationErrorCode: -1003,
            runningKeyPath: \.isAudioConverting,
            progressKeyPath: \.audioConversionProgress,
            errorMessageKeyPath: \.audioConversionErrorMessage,
            currentBatchIndexKeyPath: \.currentAudioBatchIndex,
            totalBatchCountKeyPath: \.totalAudioBatchCount,
            skippedSummaryPrefix: "Some audio files were skipped:",
            treatExportCancellationAsCancelled: true,
            startState: { self.prepareAudioConversionStartState() },
            buildOutputSettings: { self.buildAudioOutputSettings() },
            validate: { await self.validateAudioOutputSettings(for: $0) },
            makeWorkingOutputURL: { sourceURL in
                VideoConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedAudioOutputFormat)
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await VideoConversionEngine.convertAudio(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil
                ) { [weak self] progress in
                    guard let self else { return }
                    await self.updateAudioConversionProgress(
                        self.normalizedBatchProgress(
                            itemProgress: progress,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            },
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(
                    savedURL,
                    primaryOutputKeyPath: \.convertedAudioURL,
                    outputsKeyPath: \.convertedAudioURLs
                )
            },
            onSourceProcessed: removeProcessedAudioSource(_:),
            onError: applyAudioConversionError(_:)
        )
    }

    // MARK: - Progress

    private func setProgress(_ rawProgress: Double, at keyPath: ReferenceWritableKeyPath<ContentViewModel, Double>) {
        self[keyPath: keyPath] = clampedProgress(rawProgress)
    }

    private func normalizedBatchProgress(
        itemProgress: Double,
        index: Int,
        totalCount: Int
    ) -> Double {
        let base = Double(index)
        let total = Double(max(totalCount, 1))
        return (base + itemProgress) / total
    }

    private func updateConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.conversionProgress)
    }

    private func updateImageConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.imageConversionProgress)
    }

    private func updateAudioConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.audioConversionProgress)
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

    private func scheduleDeferredTask(
        _ taskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        action: @escaping @MainActor (ContentViewModel) -> Void
    ) {
        self[keyPath: taskKeyPath]?.cancel()
        self[keyPath: taskKeyPath] = makeDeferredMainActorTask(action: action)
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

    private func persistSourceSettingsIfNeeded<Settings>(
        isApplyingStoredSettings: Bool,
        sourceURL: URL?,
        settingsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [String: Settings]>,
        buildSettings: () -> Settings,
        savePersistedSettings: () -> Void
    ) {
        guard !isApplyingStoredSettings, let sourceURL else { return }

        var settingsBySourceID = self[keyPath: settingsKeyPath]
        settingsBySourceID[sourceIdentifier(for: sourceURL)] = buildSettings()
        self[keyPath: settingsKeyPath] = settingsBySourceID
        savePersistedSettings()
    }

    private func savePersistedSourceSettings<Settings, Persisted: Encodable>(
        settingsBySourceID: [String: Settings],
        mapToPersisted: (Settings) -> Persisted,
        storageKey: String,
        failureContext: String
    ) {
        let persisted = settingsBySourceID.mapValues(mapToPersisted)
        saveSettings(
            persisted,
            forKey: storageKey,
            failureContext: failureContext
        )
    }

    private func loadPersistedSourceSettings<Settings, Persisted: Decodable>(
        _ type: [String: Persisted].Type,
        storageKey: String,
        failureContext: String,
        restore: (Persisted) -> Settings
    ) -> [String: Settings] {
        guard let decoded = loadSettings(
            type,
            forKey: storageKey,
            failureContext: failureContext
        ) else {
            return [:]
        }
        return decoded.mapValues(restore)
    }

    private func scheduleVideoFormatChangeHandling() {
        scheduleDeferredTask(\.pendingVideoFormatChangeTask) { viewModel in
            viewModel.refreshVideoCodecOptions()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    private func scheduleVideoOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.pendingVideoOptionNormalizationTask) { viewModel in
            viewModel.normalizeVideoOptionDependencies()
            viewModel.persistCurrentSettingsIfNeeded()
        }
    }

    private func scheduleAudioFormatChangeHandling() {
        scheduleDeferredTask(\.pendingAudioFormatChangeTask) { viewModel in
            viewModel.refreshAudioCodecOptions()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

    private func scheduleAudioOptionNormalizationAndPersist() {
        scheduleDeferredTask(\.pendingAudioOptionNormalizationTask) { viewModel in
            viewModel.normalizeAudioOptionDependencies()
            viewModel.persistCurrentAudioSettingsIfNeeded()
        }
    }

    private func persistCurrentSettingsIfNeeded() {
        persistCurrentVideoSettingsIfNeeded()
    }

    private func persistCurrentVideoSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: isApplyingStoredSettings,
            sourceURL: sourceURL,
            settingsKeyPath: \.videoSettingsBySourceID,
            buildSettings: {
                VideoConversionSettings(
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
            },
            savePersistedSettings: savePersistedSettings
        )
    }

    private func persistCurrentImageSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: isApplyingStoredImageSettings,
            sourceURL: imageSourceURL,
            settingsKeyPath: \.imageSettingsBySourceID,
            buildSettings: {
                ImageConversionSettings(
                    outputFormatID: selectedImageOutputFormat.id,
                    resolution: selectedImageResolution,
                    quality: selectedImageQuality,
                    pngCompressionLevel: selectedPNGCompressionLevel,
                    preserveAnimation: preserveImageAnimation
                )
            },
            savePersistedSettings: savePersistedImageSettings
        )
    }

    private func persistCurrentAudioSettingsIfNeeded() {
        persistSourceSettingsIfNeeded(
            isApplyingStoredSettings: isApplyingStoredAudioSettings,
            sourceURL: audioSourceURL,
            settingsKeyPath: \.audioSettingsBySourceID,
            buildSettings: {
                AudioConversionSettings(
                    outputFormatID: selectedAudioOutputFormat.id,
                    audioEncoder: selectedAudioOutputEncoder,
                    audioMode: selectedAudioOutputMode,
                    sampleRate: selectedAudioOutputSampleRate,
                    audioBitRate: selectedAudioOutputBitRate
                )
            },
            savePersistedSettings: savePersistedAudioSettings
        )
    }

    private func withSettingsApplicationFlag(
        _ keyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        operation: () -> Void
    ) {
        self[keyPath: keyPath] = true
        defer { self[keyPath: keyPath] = false }
        operation()
    }

    private func applyStoredFormatSelection<Format>(
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String
    ) {
        guard let normalizedStoredID = normalizeStoredID(storedFormatID),
              let matchingFormat = options.first(where: { formatNormalizedID($0) == normalizedStoredID }) else {
            return
        }
        self[keyPath: selectedFormatKeyPath] = matchingFormat
    }

    private func applyStoredSourceSettings<Format>(
        applyingFlagKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String,
        applyAdditionalSettings: () -> Void,
        postApply: () -> Void
    ) {
        withSettingsApplicationFlag(applyingFlagKeyPath) {
            applyStoredFormatSelection(
                storedFormatID: storedFormatID,
                normalizeStoredID: normalizeStoredID,
                options: options,
                selectedFormatKeyPath: selectedFormatKeyPath,
                formatNormalizedID: formatNormalizedID
            )
            applyAdditionalSettings()
        }
        postApply()
    }

    private func applyStoredSettings(_ settings: VideoConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: VideoFormatOption.legacyNormalizedID(from:),
            options: outputFormatOptions,
            selectedFormatKeyPath: \.selectedOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
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
            },
            postApply: {
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    private func applyStoredImageSettings(_ settings: ImageConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredImageSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            options: imageOutputFormatOptions,
            selectedFormatKeyPath: \.selectedImageOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedImageResolution = settings.resolution
                selectedImageQuality = settings.quality
                selectedPNGCompressionLevel = settings.pngCompressionLevel
                preserveImageAnimation = settings.preserveAnimation
            },
            postApply: {
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    private func applyStoredAudioSettings(_ settings: AudioConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredAudioSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            options: audioOutputFormatOptions,
            selectedFormatKeyPath: \.selectedAudioOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedAudioOutputEncoder = settings.audioEncoder
                selectedAudioOutputMode = settings.audioMode
                selectedAudioOutputSampleRate = settings.sampleRate
                selectedAudioOutputBitRate = settings.audioBitRate
            },
            postApply: {
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }

    private func ensureSelectedFormatIsAvailable<Format>(
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String,
        preferredSelection: ([Format]) -> Format?
    ) {
        guard !options.isEmpty else { return }
        let selectedFormat = self[keyPath: selectedFormatKeyPath]
        guard !options.contains(where: { formatNormalizedID($0) == formatNormalizedID(selectedFormat) }),
              let preferredFormat = preferredSelection(options) else {
            return
        }
        self[keyPath: selectedFormatKeyPath] = preferredFormat
    }

    private func ensureSelectedImageOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: imageOutputFormatOptions,
            selectedFormatKeyPath: \.selectedImageOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: { $0.first }
        )
    }

    private func ensureSelectedAudioOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: audioOutputFormatOptions,
            selectedFormatKeyPath: \.selectedAudioOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: AudioFormatOption.defaultSelection(from:)
        )
    }

    private func ensureSelectedVideoOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: outputFormatOptions,
            selectedFormatKeyPath: \.selectedOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: VideoFormatOption.defaultSelection(from:)
        )
    }

    private func updateSelectedOptionIfNeeded<Option: Equatable>(
        options: [Option],
        selectedOptionKeyPath: ReferenceWritableKeyPath<ContentViewModel, Option>,
        preferredOption: ([Option]) -> Option?
    ) {
        let selected = self[keyPath: selectedOptionKeyPath]
        guard !options.contains(selected),
              let preferred = preferredOption(options) else {
            return
        }
        self[keyPath: selectedOptionKeyPath] = preferred
    }

    private func refreshVideoCodecOptions() {
        let format = selectedOutputFormat
        availableVideoEncoders = VideoConversionEngine.availableVideoEncoders(for: format)
        availableAudioEncoders = format.supportsAudioTrack
            ? VideoConversionEngine.availableAudioEncoders(for: format)
            : []

        updateSelectedOptionIfNeeded(
            options: availableVideoEncoders,
            selectedOptionKeyPath: \.selectedVideoEncoder,
            preferredOption: ContentViewModelSupport.preferredVideoEncoder(from:)
        )

        if format.supportsAudioTrack {
            updateSelectedOptionIfNeeded(
                options: availableAudioEncoders,
                selectedOptionKeyPath: \.selectedAudioEncoder,
                preferredOption: ContentViewModelSupport.preferredAudioEncoder(from:)
            )
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

        updateSelectedOptionIfNeeded(
            options: effectiveOptions,
            selectedOptionKeyPath: \.selectedAudioOutputEncoder,
            preferredOption: {
                ContentViewModelSupport.preferredAudioOutputEncoder(for: format, from: $0)
            }
        )

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
        savePersistedSourceSettings(
            settingsBySourceID: videoSettingsBySourceID,
            mapToPersisted: { PersistedVideoConversionSettings(from: $0) },
            storageKey: videoSettingsStorageKey,
            failureContext: "Failed to persist video settings"
        )
    }

    private func savePersistedImageSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: imageSettingsBySourceID,
            mapToPersisted: { PersistedImageConversionSettings(from: $0) },
            storageKey: imageSettingsStorageKey,
            failureContext: "Failed to persist image settings"
        )
    }

    private func savePersistedAudioSettings() {
        savePersistedSourceSettings(
            settingsBySourceID: audioSettingsBySourceID,
            mapToPersisted: { PersistedAudioConversionSettings(from: $0) },
            storageKey: audioSettingsStorageKey,
            failureContext: "Failed to persist audio settings"
        )
    }

    private func loadPersistedSettings() -> [String: VideoConversionSettings] {
        loadPersistedSourceSettings(
            [String: PersistedVideoConversionSettings].self,
            storageKey: videoSettingsStorageKey,
            failureContext: "Failed to load persisted video settings",
            restore: { $0.restoredSettings }
        )
    }

    private func loadPersistedImageSettings() -> [String: ImageConversionSettings] {
        loadPersistedSourceSettings(
            [String: PersistedImageConversionSettings].self,
            storageKey: imageSettingsStorageKey,
            failureContext: "Failed to load persisted image settings",
            restore: { $0.restoredSettings }
        )
    }

    private func loadPersistedAudioSettings() -> [String: AudioConversionSettings] {
        loadPersistedSourceSettings(
            [String: PersistedAudioConversionSettings].self,
            storageKey: audioSettingsStorageKey,
            failureContext: "Failed to load persisted audio settings",
            restore: { $0.restoredSettings }
        )
    }

}
