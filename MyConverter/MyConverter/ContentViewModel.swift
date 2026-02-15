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
    @Published var sourceURL: URL?
    @Published var convertedURL: URL?
    @Published var isImporting = false
    @Published var isConverting = false
    @Published var selectedTab: ConverterTab = .video

    @Published var selectedVideoEncoder: VideoEncoderOption = .h264GPU
    @Published var selectedResolution: ResolutionOption = .original
    @Published var selectedFrameRate: FrameRateOption = .original
    @Published var selectedVideoBitRate: VideoBitRateOption = .auto
    @Published var customVideoBitRate = "5000"
    @Published var selectedAudioEncoder: AudioEncoderOption = .aac
    @Published var selectedAudioMode: AudioModeOption = .auto
    @Published var selectedSampleRate: SampleRateOption = .hz48000
    @Published var selectedAudioBitRate: AudioBitRateOption = .auto
    @Published private(set) var conversionProgress: Double = 0

    private let supportedDropExtensions: Set<String> = ["mkv", "mov", "mp4"]

    var canConvert: Bool {
        sourceURL != nil && !isConverting && isVideoSettingsValid
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

    var normalizedCustomVideoBitRateKbps: Int? {
        let trimmed = customVideoBitRate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Int(sanitized), value > 0 else { return nil }
        return value
    }

    var preferredImportTypes: [UTType] {
        let mkvType = UTType(filenameExtension: "mkv")
        return [mkvType, .movie].compactMap { $0 }
    }

    func requestFileImport() {
        isImporting = true
    }

    func clearSelectedSource() {
        sourceURL = nil
        convertedURL = nil
    }

    func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selected = urls.first else { return }
            sourceURL = selected
            convertedURL = nil
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
                self?.acceptDroppedFile(finalURL)
            }
        }

        return true
    }

    func startConversion() {
        Task {
            await convert()
        }
    }

    private func acceptDroppedFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        guard supportedDropExtensions.contains(ext) else { return }

        sourceURL = url
        convertedURL = nil
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
        conversionProgress = 0
    }

    private func applyConversionError(_ error: Error) {
        if let conversionError = error as? ConversionError {
            print("Conversion failed: \(conversionError.debugInfo)")
        } else {
            print("Conversion failed: \(error.localizedDescription)")
        }
    }

    private func convert() async {
        guard let sourceURL else {
            print("No file to convert.")
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

            let destinationURL = VideoConversionEngine.uniqueOutputURL(for: sourceURL, in: outputDirectory)
            let workingOutputURL = VideoConversionEngine.temporaryOutputURL(for: sourceURL)
            defer {
                if FileManager.default.fileExists(atPath: workingOutputURL.path) {
                    try? FileManager.default.removeItem(at: workingOutputURL)
                }
            }

            let output = try await VideoConversionEngine.convertToMP4(
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
}
