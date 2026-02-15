import Combine
import Foundation
import UniformTypeIdentifiers

enum ConverterTab: String, CaseIterable, Identifiable {
    case video
    case image
    case audio
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video:
            return "Convert Video"
        case .image:
            return "Convert Image"
        case .audio:
            return "Convert Audio"
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

    // Video state
    @Published private(set) var sourceURL: URL?
    @Published private(set) var convertedURL: URL?
    @Published private(set) var conversionErrorMessage: String?
    @Published private(set) var sourceCompatibilityErrorMessage: String?
    @Published private(set) var sourceCompatibilityWarningMessage: String?
    @Published private(set) var isAnalyzingSource = false
    @Published var isConverting = false
    @Published private(set) var conversionProgress: Double = 0
    @Published private(set) var availableOutputFormats: [VideoContainerOption] = VideoContainerOption.allCases

    // Image state
    @Published private(set) var imageSourceURL: URL?
    @Published private(set) var convertedImageURL: URL?
    @Published private(set) var imageConversionErrorMessage: String?
    @Published private(set) var imageSourceCompatibilityErrorMessage: String?
    @Published private(set) var imageSourceCompatibilityWarningMessage: String?
    @Published private(set) var isAnalyzingImageSource = false
    @Published var isImageConverting = false
    @Published private(set) var imageConversionProgress: Double = 0
    @Published private(set) var availableImageOutputFormats: [ImageContainerOption] = ImageContainerOption.allCases

    @Published var isImporting = false
    @Published var selectedTab: ConverterTab = .video

    // Video options
    @Published var selectedOutputFormat: VideoContainerOption = .mp4 {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedVideoEncoder: VideoEncoderOption = .h264GPU {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedResolution: ResolutionOption = .original {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedFrameRate: FrameRateOption = .original {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedVideoBitRate: VideoBitRateOption = .auto {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var customVideoBitRate = "5000" {
        didSet { persistCurrentSettingsIfNeeded() }
    }
    @Published var selectedAudioEncoder: AudioEncoderOption = .aac {
        didSet { persistCurrentSettingsIfNeeded() }
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
    @Published var selectedImageOutputFormat: ImageContainerOption = .png {
        didSet { persistCurrentImageSettingsIfNeeded() }
    }
    @Published var selectedImageResolution: ResolutionOption = .original {
        didSet { persistCurrentImageSettingsIfNeeded() }
    }
    @Published var selectedImageQuality: ImageQualityOption = .high {
        didSet { persistCurrentImageSettingsIfNeeded() }
    }

    private struct VideoConversionSettings {
        var outputFormat: VideoContainerOption = .mp4
        var videoEncoder: VideoEncoderOption = .h264GPU
        var resolution: ResolutionOption = .original
        var frameRate: FrameRateOption = .original
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
        var videoBitRate: String
        var customVideoBitRate: String
        var audioEncoder: String
        var audioMode: String
        var sampleRate: String
        var audioBitRate: String

        init(from settings: VideoConversionSettings) {
            outputFormat = settings.outputFormat.rawValue
            videoEncoder = settings.videoEncoder.rawValue
            resolution = settings.resolution.rawValue
            frameRate = settings.frameRate.rawValue
            videoBitRate = settings.videoBitRate.rawValue
            customVideoBitRate = settings.customVideoBitRate
            audioEncoder = settings.audioEncoder.rawValue
            audioMode = settings.audioMode.rawValue
            sampleRate = settings.sampleRate.rawValue
            audioBitRate = settings.audioBitRate.rawValue
        }

        var restoredSettings: VideoConversionSettings {
            VideoConversionSettings(
                outputFormat: VideoContainerOption(rawValue: outputFormat) ?? .mp4,
                videoEncoder: VideoEncoderOption(rawValue: videoEncoder) ?? .h264GPU,
                resolution: ResolutionOption(rawValue: resolution) ?? .original,
                frameRate: FrameRateOption(rawValue: frameRate) ?? .original,
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
        var outputFormat: ImageContainerOption = .png
        var resolution: ResolutionOption = .original
        var quality: ImageQualityOption = .high
    }

    private struct PersistedImageConversionSettings: Codable {
        var outputFormat: String
        var resolution: String
        var quality: String

        init(from settings: ImageConversionSettings) {
            outputFormat = settings.outputFormat.rawValue
            resolution = settings.resolution.rawValue
            quality = settings.quality.rawValue
        }

        var restoredSettings: ImageConversionSettings {
            ImageConversionSettings(
                outputFormat: ImageContainerOption(rawValue: outputFormat) ?? .png,
                resolution: ResolutionOption(rawValue: resolution) ?? .original,
                quality: ImageQualityOption(rawValue: quality) ?? .high
            )
        }
    }

    private var videoSettingsBySourceID: [String: VideoConversionSettings] = [:]
    private var imageSettingsBySourceID: [String: ImageConversionSettings] = [:]

    private var isApplyingStoredSettings = false
    private var isApplyingStoredImageSettings = false

    private var sourceAnalysisTask: Task<Void, Never>?
    private var conversionTask: Task<Void, Never>?
    private var imageSourceAnalysisTask: Task<Void, Never>?
    private var imageConversionTask: Task<Void, Never>?

    private let videoSettingsStorageKey = "ContentViewModel.VideoSettingsBySource"
    private let imageSettingsStorageKey = "ContentViewModel.ImageSettingsBySource"

    init() {
        videoSettingsBySourceID = loadPersistedSettings()
        imageSettingsBySourceID = loadPersistedImageSettings()
    }

    // MARK: - Video Computed Properties

    var canConvert: Bool {
        sourceURL != nil &&
            !isConverting &&
            !isAnalyzingSource &&
            sourceCompatibilityErrorMessage == nil &&
            isVideoSettingsValid &&
            availableOutputFormats.contains(selectedOutputFormat)
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
        if selectedVideoBitRate == .custom {
            return normalizedCustomVideoBitRateKbps != nil
        }
        return true
    }

    var videoSettingsValidationMessage: String? {
        if let sourceCompatibilityErrorMessage {
            return sourceCompatibilityErrorMessage
        }
        if selectedVideoBitRate == .custom && normalizedCustomVideoBitRateKbps == nil {
            return "Please enter an integer greater than 1 for Custom Bitrate (Kbps)."
        }
        if sourceURL != nil && !availableOutputFormats.contains(selectedOutputFormat) {
            return "Selected container is not available for this source."
        }
        return nil
    }

    var outputFormatOptions: [VideoContainerOption] {
        if sourceURL == nil || availableOutputFormats.isEmpty {
            return VideoContainerOption.allCases
        }
        return availableOutputFormats
    }

    var normalizedCustomVideoBitRateKbps: Int? {
        let trimmed = customVideoBitRate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Int(sanitized), value > 0 else { return nil }
        return value
    }

    // MARK: - Image Computed Properties

    var canConvertImage: Bool {
        imageSourceURL != nil &&
            !isImageConverting &&
            !isAnalyzingImageSource &&
            imageSourceCompatibilityErrorMessage == nil &&
            availableImageOutputFormats.contains(selectedImageOutputFormat)
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

    var imageOutputFormatOptions: [ImageContainerOption] {
        if imageSourceURL == nil || availableImageOutputFormats.isEmpty {
            return ImageContainerOption.allCases
        }
        return availableImageOutputFormats
    }

    var imageSettingsValidationMessage: String? {
        if let imageSourceCompatibilityErrorMessage {
            return imageSourceCompatibilityErrorMessage
        }
        if imageSourceURL != nil && !availableImageOutputFormats.contains(selectedImageOutputFormat) {
            return "Selected output format is not available for this source."
        }
        return nil
    }

    // MARK: - Input Handling

    var preferredImportTypes: [UTType] {
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

    func clearSelectedSource() {
        clearSelectedVideoSource()
    }

    func clearSelectedVideoSource() {
        sourceAnalysisTask?.cancel()
        sourceAnalysisTask = nil

        sourceURL = nil
        convertedURL = nil
        conversionErrorMessage = nil
        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil
        isAnalyzingSource = false
        availableOutputFormats = VideoContainerOption.allCases

        applyStoredSettings(.init())
    }

    func clearSelectedImageSource() {
        imageSourceAnalysisTask?.cancel()
        imageSourceAnalysisTask = nil

        imageSourceURL = nil
        convertedImageURL = nil
        imageConversionErrorMessage = nil
        imageSourceCompatibilityErrorMessage = nil
        imageSourceCompatibilityWarningMessage = nil
        isAnalyzingImageSource = false
        availableImageOutputFormats = ImageContainerOption.allCases

        applyStoredImageSettings(.init())
    }

    func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selected = urls.first else { return }
            switch selectedTab {
            case .video:
                applySelectedSource(selected)
            case .image:
                applySelectedImageSource(selected)
            case .audio, .about:
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
        handleDroppedFile(providers: providers) { [weak self] url in
            self?.applySelectedSource(url)
        }
    }

    func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        handleDroppedFile(providers: providers) { [weak self] url in
            self?.applySelectedImageSource(url)
        }
    }

    private func handleDroppedFile(
        providers: [NSItemProvider],
        onResolvedURL: @escaping @MainActor (URL) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var finalURL: URL?

            if let data = item as? Data {
                finalURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                finalURL = url
            }

            guard let finalURL else { return }

            Task { @MainActor in
                onResolvedURL(finalURL)
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

    // MARK: - Video Source / Analyze

    private func applySelectedSource(_ url: URL) {
        sourceAnalysisTask?.cancel()
        sourceAnalysisTask = nil

        sourceURL = url
        convertedURL = nil
        conversionErrorMessage = nil
        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil

        let sourceID = sourceIdentifier(for: url)
        let stored = videoSettingsBySourceID[sourceID] ?? VideoConversionSettings()
        applyStoredSettings(stored)

        analyzeSourceCompatibility(for: url)
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
               !capabilities.availableOutputFormats.contains(self.selectedOutputFormat) {
                self.selectedOutputFormat = first
            }

            self.persistCurrentSettingsIfNeeded()
        }
    }

    // MARK: - Image Source / Analyze

    private func applySelectedImageSource(_ url: URL) {
        imageSourceAnalysisTask?.cancel()
        imageSourceAnalysisTask = nil

        imageSourceURL = url
        convertedImageURL = nil
        imageConversionErrorMessage = nil
        imageSourceCompatibilityErrorMessage = nil
        imageSourceCompatibilityWarningMessage = nil

        let sourceID = sourceIdentifier(for: url)
        let stored = imageSettingsBySourceID[sourceID] ?? ImageConversionSettings()
        applyStoredImageSettings(stored)

        analyzeImageSourceCompatibility(for: url)
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
            self.availableImageOutputFormats = capabilities.availableOutputFormats
            self.imageSourceCompatibilityWarningMessage = capabilities.warningMessage
            self.imageSourceCompatibilityErrorMessage = capabilities.errorMessage

            if let first = capabilities.availableOutputFormats.first,
               !capabilities.availableOutputFormats.contains(self.selectedImageOutputFormat) {
                self.selectedImageOutputFormat = first
            }

            self.persistCurrentImageSettingsIfNeeded()
        }
    }

    // MARK: - Build Settings

    private func buildVideoOutputSettings() throws -> VideoOutputSettings {
        let videoBitRateKbps: Int?
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

        return VideoOutputSettings(
            containerFormat: selectedOutputFormat,
            videoCodecCandidates: selectedVideoEncoder.codecCandidates,
            useHEVCTag: selectedVideoEncoder.isHEVC,
            resolution: selectedResolution.dimensions,
            frameRate: selectedFrameRate.fps,
            videoBitRateKbps: videoBitRateKbps,
            audioCodec: selectedAudioEncoder.codecName,
            audioChannels: selectedAudioMode.channelCount,
            sampleRate: selectedSampleRate.hertz,
            audioBitRateKbps: selectedAudioBitRate.kbps
        )
    }

    private func buildImageOutputSettings() -> ImageOutputSettings {
        let compressionQuality: Double?
        if selectedImageOutputFormat.supportsCompressionQuality {
            compressionQuality = selectedImageQuality.compressionQuality
        } else {
            compressionQuality = nil
        }

        return ImageOutputSettings(
            containerFormat: selectedImageOutputFormat,
            resolution: selectedImageResolution.dimensions,
            compressionQuality: compressionQuality
        )
    }

    // MARK: - Conversion State / Errors

    private func prepareConversionStartState() {
        isConverting = true
        convertedURL = nil
        conversionErrorMessage = nil
        conversionProgress = 0
    }

    private func prepareImageConversionStartState() {
        isImageConverting = true
        convertedImageURL = nil
        imageConversionErrorMessage = nil
        imageConversionProgress = 0
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

        let shouldStopSourceAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopSourceAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            defer { isConverting = false }
            try Task.checkCancellation()

            let outputDirectory = try VideoConversionEngine.sandboxOutputDirectory(
                bundleIdentifier: Bundle.main.bundleIdentifier
            )

            let destinationURL = VideoConversionEngine.uniqueOutputURL(
                for: sourceURL,
                format: selectedOutputFormat,
                in: outputDirectory
            )
            let workingOutputURL = VideoConversionEngine.temporaryOutputURL(
                for: sourceURL,
                format: selectedOutputFormat
            )
            defer {
                if FileManager.default.fileExists(atPath: workingOutputURL.path) {
                    try? FileManager.default.removeItem(at: workingOutputURL)
                }
            }

            let output = try await VideoConversionEngine.convert(
                inputURL: sourceURL,
                outputURL: workingOutputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: nil
            ) { [weak self] progress in
                await self?.updateConversionProgress(progress)
            }
            try Task.checkCancellation()

            convertedURL = try VideoConversionEngine.saveConvertedOutput(from: output, to: destinationURL)
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

        let shouldStopSourceAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopSourceAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            defer { isImageConverting = false }
            try Task.checkCancellation()

            let outputDirectory = try VideoConversionEngine.sandboxOutputDirectory(
                bundleIdentifier: Bundle.main.bundleIdentifier
            )

            let destinationURL = ImageConversionEngine.uniqueOutputURL(
                for: sourceURL,
                format: selectedImageOutputFormat,
                in: outputDirectory
            )
            let workingOutputURL = ImageConversionEngine.temporaryOutputURL(
                for: sourceURL,
                format: selectedImageOutputFormat
            )
            defer {
                if FileManager.default.fileExists(atPath: workingOutputURL.path) {
                    try? FileManager.default.removeItem(at: workingOutputURL)
                }
            }

            let output = try await ImageConversionEngine.convert(
                inputURL: sourceURL,
                outputURL: workingOutputURL,
                outputSettings: outputSettings
            ) { [weak self] progress in
                await self?.updateImageConversionProgress(progress)
            }
            try Task.checkCancellation()

            convertedImageURL = try VideoConversionEngine.saveConvertedOutput(from: output, to: destinationURL)
            imageConversionProgress = 1
        } catch is CancellationError {
            imageConversionProgress = 0
            imageConversionErrorMessage = nil
        } catch {
            applyImageConversionError(error)
        }
    }

    // MARK: - Progress

    private func updateConversionProgress(_ rawProgress: Double) {
        conversionProgress = min(max(rawProgress, 0), 1)
    }

    private func updateImageConversionProgress(_ rawProgress: Double) {
        imageConversionProgress = min(max(rawProgress, 0), 1)
    }

    // MARK: - Persistence

    private func sourceIdentifier(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func persistCurrentSettingsIfNeeded() {
        persistCurrentVideoSettingsIfNeeded()
    }

    private func persistCurrentVideoSettingsIfNeeded() {
        guard !isApplyingStoredSettings, let sourceURL else { return }

        videoSettingsBySourceID[sourceIdentifier(for: sourceURL)] = VideoConversionSettings(
            outputFormat: selectedOutputFormat,
            videoEncoder: selectedVideoEncoder,
            resolution: selectedResolution,
            frameRate: selectedFrameRate,
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
            outputFormat: selectedImageOutputFormat,
            resolution: selectedImageResolution,
            quality: selectedImageQuality
        )
        savePersistedImageSettings()
    }

    private func applyStoredSettings(_ settings: VideoConversionSettings) {
        isApplyingStoredSettings = true
        defer { isApplyingStoredSettings = false }

        selectedOutputFormat = settings.outputFormat
        selectedVideoEncoder = settings.videoEncoder
        selectedResolution = settings.resolution
        selectedFrameRate = settings.frameRate
        selectedVideoBitRate = settings.videoBitRate
        customVideoBitRate = settings.customVideoBitRate
        selectedAudioEncoder = settings.audioEncoder
        selectedAudioMode = settings.audioMode
        selectedSampleRate = settings.sampleRate
        selectedAudioBitRate = settings.audioBitRate
    }

    private func applyStoredImageSettings(_ settings: ImageConversionSettings) {
        isApplyingStoredImageSettings = true
        defer { isApplyingStoredImageSettings = false }

        selectedImageOutputFormat = settings.outputFormat
        selectedImageResolution = settings.resolution
        selectedImageQuality = settings.quality
    }

    private func savePersistedSettings() {
        let persisted = videoSettingsBySourceID.mapValues { PersistedVideoConversionSettings(from: $0) }
        do {
            let data = try JSONEncoder().encode(persisted)
            UserDefaults.standard.set(data, forKey: videoSettingsStorageKey)
        } catch {
            print("Failed to persist video settings: \(error.localizedDescription)")
        }
    }

    private func savePersistedImageSettings() {
        let persisted = imageSettingsBySourceID.mapValues { PersistedImageConversionSettings(from: $0) }
        do {
            let data = try JSONEncoder().encode(persisted)
            UserDefaults.standard.set(data, forKey: imageSettingsStorageKey)
        } catch {
            print("Failed to persist image settings: \(error.localizedDescription)")
        }
    }

    private func loadPersistedSettings() -> [String: VideoConversionSettings] {
        guard let data = UserDefaults.standard.data(forKey: videoSettingsStorageKey) else {
            return [:]
        }

        do {
            let decoded = try JSONDecoder().decode([String: PersistedVideoConversionSettings].self, from: data)
            return decoded.mapValues { $0.restoredSettings }
        } catch {
            print("Failed to load persisted video settings: \(error.localizedDescription)")
            return [:]
        }
    }

    private func loadPersistedImageSettings() -> [String: ImageConversionSettings] {
        guard let data = UserDefaults.standard.data(forKey: imageSettingsStorageKey) else {
            return [:]
        }

        do {
            let decoded = try JSONDecoder().decode([String: PersistedImageConversionSettings].self, from: data)
            return decoded.mapValues { $0.restoredSettings }
        } catch {
            print("Failed to load persisted image settings: \(error.localizedDescription)")
            return [:]
        }
    }

    // MARK: - Status

    private var conversionStatus: (message: String, level: ConversionStatusLevel) {
        if isConverting {
            return ("Conversion in progress...", .normal)
        }

        if isAnalyzingSource {
            return ("Analyzing source compatibility...", .normal)
        }

        if let error = conversionErrorMessage, !error.isEmpty {
            return (error, .error)
        }

        if let validation = videoSettingsValidationMessage {
            return (validation, .error)
        }

        if let warning = sourceCompatibilityWarningMessage, !warning.isEmpty {
            return (warning, .warning)
        }

        return ("Ready", .normal)
    }

    private var imageConversionStatus: (message: String, level: ConversionStatusLevel) {
        if isImageConverting {
            return ("Conversion in progress...", .normal)
        }

        if isAnalyzingImageSource {
            return ("Analyzing source compatibility...", .normal)
        }

        if let error = imageConversionErrorMessage, !error.isEmpty {
            return (error, .error)
        }

        if let validation = imageSettingsValidationMessage {
            return (validation, .error)
        }

        if let warning = imageSourceCompatibilityWarningMessage, !warning.isEmpty {
            return (warning, .warning)
        }

        return ("Ready", .normal)
    }
}
