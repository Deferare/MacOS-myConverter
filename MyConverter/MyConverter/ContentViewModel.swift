import Combine
import Foundation
import UniformTypeIdentifiers

enum ConverterTab: String, CaseIterable, Identifiable {
    case video
    case image
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video:
            return "Convert Video"
        case .image:
            return "Convert Image"
        case .audio:
            return "Convert Audio"
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
        }
    }
}

@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var sourceURL: URL?
    @Published private(set) var convertedURL: URL?
    @Published private(set) var conversionErrorMessage: String?
    @Published private(set) var sourceCompatibilityErrorMessage: String?
    @Published private(set) var sourceCompatibilityWarningMessage: String?
    @Published private(set) var isAnalyzingSource = false

    @Published var isImporting = false
    @Published var isConverting = false
    @Published var selectedTab: ConverterTab = .video

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
    @Published private(set) var conversionProgress: Double = 0
    @Published private(set) var availableOutputFormats: [VideoContainerOption] = VideoContainerOption.allCases

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

    private var settingsBySourceID: [String: VideoConversionSettings] = [:]
    private var isApplyingStoredSettings = false
    private var sourceAnalysisTask: Task<Void, Never>?
    private let settingsStorageKey = "ContentViewModel.VideoSettingsBySource"

    init() {
        settingsBySourceID = loadPersistedSettings()
    }

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

    var preferredImportTypes: [UTType] {
        let mkvType = UTType(filenameExtension: "mkv")
        return [.movie, .audiovisualContent, mkvType].compactMap { $0 }
    }

    func requestFileImport() {
        isImporting = true
    }

    func clearSelectedSource() {
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

    func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selected = urls.first else { return }
            applySelectedSource(selected)
        case .failure(let error):
            print("Failed to select file: \(error.localizedDescription)")
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
            var finalURL: URL?

            if let data = item as? Data {
                finalURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                finalURL = url
            }

            guard let finalURL else { return }

            Task { @MainActor [weak self] in
                self?.applySelectedSource(finalURL)
            }
        }

        return true
    }

    func startConversion() {
        Task {
            await convert()
        }
    }

    private func applySelectedSource(_ url: URL) {
        sourceAnalysisTask?.cancel()
        sourceAnalysisTask = nil

        sourceURL = url
        convertedURL = nil
        conversionErrorMessage = nil
        sourceCompatibilityErrorMessage = nil
        sourceCompatibilityWarningMessage = nil

        let sourceID = sourceIdentifier(for: url)
        let stored = settingsBySourceID[sourceID] ?? VideoConversionSettings()
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

    private func prepareConversionStartState() {
        isConverting = true
        convertedURL = nil
        conversionErrorMessage = nil
        conversionProgress = 0
    }

    private func applyConversionError(_ error: Error) {
        conversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

        if let conversionError = error as? ConversionError {
            print("Conversion failed: \(conversionError.debugInfo)")
        } else {
            print("Conversion failed: \(error.localizedDescription)")
        }
    }

    private func convert() async {
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

            convertedURL = try VideoConversionEngine.saveConvertedOutput(from: output, to: destinationURL)
            conversionProgress = 1
        } catch {
            applyConversionError(error)
        }
    }

    private func updateConversionProgress(_ rawProgress: Double) {
        conversionProgress = min(max(rawProgress, 0), 1)
    }

    private func sourceIdentifier(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func persistCurrentSettingsIfNeeded() {
        guard !isApplyingStoredSettings, let sourceURL else { return }

        settingsBySourceID[sourceIdentifier(for: sourceURL)] = VideoConversionSettings(
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

    private func savePersistedSettings() {
        let persisted = settingsBySourceID.mapValues { PersistedVideoConversionSettings(from: $0) }
        do {
            let data = try JSONEncoder().encode(persisted)
            UserDefaults.standard.set(data, forKey: settingsStorageKey)
        } catch {
            print("Failed to persist video settings: \(error.localizedDescription)")
        }
    }

    private func loadPersistedSettings() -> [String: VideoConversionSettings] {
        guard let data = UserDefaults.standard.data(forKey: settingsStorageKey) else {
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
}
