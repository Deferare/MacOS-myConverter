//
//  ContentView.swift
//  MyConverter
//
//  Created by JiHoon K on 2/14/26.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    private enum ConverterTab: String, CaseIterable, Identifiable {
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

    private enum VideoEncoderOption: String, CaseIterable, Identifiable {
        case h265CPU = "H.265(CPU)"
        case h265GPU = "H.265(GPU)"
        case h264CPU = "H.264(CPU)"
        case h264GPU = "H.264(GPU)"

        var id: String { rawValue }

        var codecCandidates: [String] {
            switch self {
            case .h265CPU:
                return ["libx265", "hevc", "h264", "mpeg4"]
            case .h265GPU:
                return ["hevc_videotoolbox", "hevc", "h264_videotoolbox", "h264", "mpeg4"]
            case .h264CPU:
                return ["libx264", "h264", "mpeg4"]
            case .h264GPU:
                return ["h264_videotoolbox", "h264", "mpeg4"]
            }
        }

        var isHEVC: Bool {
            switch self {
            case .h265CPU, .h265GPU:
                return true
            case .h264CPU, .h264GPU:
                return false
            }
        }
    }

    private enum ResolutionOption: String, CaseIterable, Identifiable {
        case original = "Original"
        case r3840x2160 = "3840x2160"
        case r2560x1440 = "2560x1440"
        case r1920x1080 = "1920x1080"
        case r1280x720 = "1280x720"
        case r640x480 = "640x480"
        case r480x360 = "480x360"
        case r320x240 = "320x240"
        case r192x144 = "192x144"

        var id: String { rawValue }

        var dimensions: (width: Int, height: Int)? {
            switch self {
            case .original:
                return nil
            case .r3840x2160:
                return (3840, 2160)
            case .r2560x1440:
                return (2560, 1440)
            case .r1920x1080:
                return (1920, 1080)
            case .r1280x720:
                return (1280, 720)
            case .r640x480:
                return (640, 480)
            case .r480x360:
                return (480, 360)
            case .r320x240:
                return (320, 240)
            case .r192x144:
                return (192, 144)
            }
        }
    }

    private enum FrameRateOption: String, CaseIterable, Identifiable {
        case original = "Original"
        case fps120 = "120 FPS"
        case fps90 = "90 FPS"
        case fps60 = "60 FPS"
        case fps50 = "50 FPS"
        case fps40 = "40 FPS"
        case fps30 = "30 FPS"
        case fps25 = "25 FPS"
        case fps24 = "24 FPS"
        case fps20 = "20 FPS"
        case fps15 = "15 FPS"
        case fps12 = "12 FPS"
        case fps10 = "10 FPS"
        case fps5 = "5 FPS"
        case fps1 = "1 FPS"

        var id: String { rawValue }

        var fps: Int? {
            switch self {
            case .original:
                return nil
            case .fps120:
                return 120
            case .fps90:
                return 90
            case .fps60:
                return 60
            case .fps50:
                return 50
            case .fps40:
                return 40
            case .fps30:
                return 30
            case .fps25:
                return 25
            case .fps24:
                return 24
            case .fps20:
                return 20
            case .fps15:
                return 15
            case .fps12:
                return 12
            case .fps10:
                return 10
            case .fps5:
                return 5
            case .fps1:
                return 1
            }
        }
    }

    private enum VideoBitRateOption: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case kbps50000 = "50000 Kbps"
        case kbps40000 = "40000 Kbps"
        case kbps30000 = "30000 Kbps"
        case kbps20000 = "20000 Kbps"
        case kbps10000 = "10000 Kbps"
        case kbps9000 = "9000 Kbps"
        case kbps8000 = "8000 Kbps"
        case kbps7000 = "7000 Kbps"
        case kbps6000 = "6000 Kbps"
        case kbps5000 = "5000 Kbps"
        case kbps4000 = "4000 Kbps"
        case kbps3000 = "3000 Kbps"
        case kbps2000 = "2000 Kbps"
        case kbps1000 = "1000 Kbps"
        case kbps500 = "500 Kbps"
        case custom = "Custom"

        var id: String { rawValue }

        var kbps: Int? {
            switch self {
            case .auto, .custom:
                return nil
            case .kbps50000:
                return 50000
            case .kbps40000:
                return 40000
            case .kbps30000:
                return 30000
            case .kbps20000:
                return 20000
            case .kbps10000:
                return 10000
            case .kbps9000:
                return 9000
            case .kbps8000:
                return 8000
            case .kbps7000:
                return 7000
            case .kbps6000:
                return 6000
            case .kbps5000:
                return 5000
            case .kbps4000:
                return 4000
            case .kbps3000:
                return 3000
            case .kbps2000:
                return 2000
            case .kbps1000:
                return 1000
            case .kbps500:
                return 500
            }
        }
    }

    private enum AudioEncoderOption: String, CaseIterable, Identifiable {
        case aac = "AAC"

        var id: String { rawValue }

        var codecName: String { "aac" }
    }

    private enum AudioModeOption: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case stereo = "Stereo"
        case mono = "Mono"

        var id: String { rawValue }

        var channelCount: Int? {
            switch self {
            case .auto:
                return nil
            case .stereo:
                return 2
            case .mono:
                return 1
            }
        }
    }

    private enum SampleRateOption: String, CaseIterable, Identifiable {
        case hz48000 = "48000 HZ"
        case hz44100 = "44100 HZ"
        case hz32000 = "32000 HZ"
        case hz16000 = "16000 HZ"

        var id: String { rawValue }

        var hertz: Int {
            switch self {
            case .hz48000:
                return 48000
            case .hz44100:
                return 44100
            case .hz32000:
                return 32000
            case .hz16000:
                return 16000
            }
        }
    }

    private enum AudioBitRateOption: String, CaseIterable, Identifiable {
        case auto = "Auto"
        case kbps320 = "320 Kbps"
        case kbps256 = "256 Kbps"
        case kbps192 = "192 Kbps"
        case kbps160 = "160 Kbps"
        case kbps128 = "128 Kbps"
        case kbps96 = "96 Kbps"
        case kbps80 = "80 Kbps"
        case kbps64 = "64 Kbps"

        var id: String { rawValue }

        var kbps: Int? {
            switch self {
            case .auto:
                return nil
            case .kbps320:
                return 320
            case .kbps256:
                return 256
            case .kbps192:
                return 192
            case .kbps160:
                return 160
            case .kbps128:
                return 128
            case .kbps96:
                return 96
            case .kbps80:
                return 80
            case .kbps64:
                return 64
            }
        }
    }

    private struct VideoOutputSettings {
        let videoEncoder: VideoEncoderOption
        let resolution: ResolutionOption
        let frameRate: FrameRateOption
        let videoBitRateKbps: Int?
        let audioEncoder: AudioEncoderOption
        let audioMode: AudioModeOption
        let sampleRate: SampleRateOption
        let audioBitRateKbps: Int?
    }

    @State private var sourceURL: URL?
    @State private var convertedURL: URL?
    @State private var isImporting = false
    @State private var isConverting = false
    @State private var selectedTab: ConverterTab = .video
    @State private var imageOutputFormat = "PNG"
    @State private var imageKeepMetadata = true
    @State private var audioOutputFormat = "M4A"
    @State private var audioBitrateKbps = 192
    @State private var selectedVideoEncoder: VideoEncoderOption = .h264GPU
    @State private var selectedResolution: ResolutionOption = .original
    @State private var selectedFrameRate: FrameRateOption = .original
    @State private var selectedVideoBitRate: VideoBitRateOption = .auto
    @State private var customVideoBitRate = "5000"
    @State private var selectedAudioEncoder: AudioEncoderOption = .aac
    @State private var selectedAudioMode: AudioModeOption = .auto
    @State private var selectedSampleRate: SampleRateOption = .hz48000
    @State private var selectedAudioBitRate: AudioBitRateOption = .auto
    @State private var conversionProgress: Double = 0

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(ConverterTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("MyConverter")
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            switch selectedTab {
            case .video:
                videoDetailView
            case .image:
                imageDetailView
            case .audio:
                audioDetailView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            if selectedTab == .video {
                Button {
                    startConversion()
                } label: {
                    Label("변환", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                }
                .disabled(!canConvert)
            }
        }
        .frame(minWidth: 980, minHeight: 620)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: preferredImportTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selected = urls.first else { return }
                sourceURL = selected
                convertedURL = nil
            case .failure(let error):
                print("파일 선택에 실패했습니다: \(error.localizedDescription)")
            }
        }
    }

    private var videoDetailView: some View {
        Form {
            Section("입력 파일") {
                HStack(spacing: 12) {
                    Button {
                        isImporting = true
                    } label: {
                        Label(sourceURL == nil ? "MKV 파일 선택" : "다른 MKV 선택", systemImage: "doc")
                    }
                    .disabled(isConverting)
                    .keyboardShortcut("o", modifiers: [.command])

                    Spacer(minLength: 0)

                    if let sourceURL {
                        Text(sourceURL.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
            }

            Section("출력 설정") {
                LabeledContent("컨테이너") { Text("MP4") }

                Picker("Video Encoder", selection: $selectedVideoEncoder) {
                    ForEach(VideoEncoderOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Resolution", selection: $selectedResolution) {
                    ForEach(ResolutionOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Frame Rate", selection: $selectedFrameRate) {
                    ForEach(FrameRateOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Video Bit Rate", selection: $selectedVideoBitRate) {
                    ForEach(VideoBitRateOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                if selectedVideoBitRate == .custom {
                    TextField("Custom Kbps (예: 5000)", text: $customVideoBitRate)
                        .textFieldStyle(.roundedBorder)

                    if normalizedCustomVideoBitRateKbps == nil {
                        Text("Custom 비트레이트는 1 이상 정수(Kbps)로 입력해 주세요.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Picker("Audio Encoder", selection: $selectedAudioEncoder) {
                    ForEach(AudioEncoderOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Audio Mode", selection: $selectedAudioMode) {
                    ForEach(AudioModeOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Sample Rate", selection: $selectedSampleRate) {
                    ForEach(SampleRateOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Audio Bit Rate", selection: $selectedAudioBitRate) {
                    ForEach(AudioBitRateOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("결과 파일") {
                if let convertedURL {
                    LabeledContent("파일명") {
                        Text(convertedURL.lastPathComponent)
                            .textSelection(.enabled)
                    }

                    LabeledContent("위치") {
                        Text(convertedURL.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 12) {
                        ShareLink(item: convertedURL) {
                            Label("공유", systemImage: "square.and.arrow.up")
                        }

                        #if os(macOS)
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([convertedURL])
                        } label: {
                            Label("Finder에서 열기", systemImage: "folder")
                        }
                        #endif
                    }
                } else {
                    Text("변환이 완료되면 결과 파일이 여기에 표시됩니다.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            videoConversionControls
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
        .navigationTitle("Convert Video")
    }

    private var videoConversionControls: some View {
        HStack(spacing: 12) {
            Button {
                startConversion()
            } label: {
                Label(
                    isConverting ? "변환 중" : "변환하기",
                    systemImage: "play.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canConvert)

            ProgressView(value: displayedConversionProgress, total: 1.0)
                .progressViewStyle(.linear)
                .tint(progressTintColor)
                .frame(maxWidth: .infinity)

            Text(progressPercentageText)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var imageDetailView: some View {
        Form {
            Section("입력 이미지") {
                Label("이미지 파일을 선택해 변환합니다.", systemImage: "photo")
                Button("이미지 파일 선택 (준비 중)") {}
                    .disabled(true)
            }

            Section("출력 옵션") {
                Picker("포맷", selection: $imageOutputFormat) {
                    Text("PNG").tag("PNG")
                    Text("JPEG").tag("JPEG")
                    Text("HEIC").tag("HEIC")
                    Text("WEBP").tag("WEBP")
                }
                Toggle("메타데이터 유지", isOn: $imageKeepMetadata)
            }

            Section("실행") {
                Button("이미지 변환 시작") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)

                Text("이미지 변환 엔진은 다음 단계에서 연결됩니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Convert Image")
    }

    private var audioDetailView: some View {
        Form {
            Section("입력 오디오") {
                Label("오디오 파일을 선택해 변환합니다.", systemImage: "waveform")
                Button("오디오 파일 선택 (준비 중)") {}
                    .disabled(true)
            }

            Section("출력 옵션") {
                Picker("포맷", selection: $audioOutputFormat) {
                    Text("M4A").tag("M4A")
                    Text("MP3").tag("MP3")
                    Text("WAV").tag("WAV")
                    Text("FLAC").tag("FLAC")
                }
                Stepper("비트레이트 \(audioBitrateKbps) kbps", value: $audioBitrateKbps, in: 96...320, step: 32)
            }

            Section("실행") {
                Button("오디오 변환 시작") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)

                Text("오디오 변환 엔진은 다음 단계에서 연결됩니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Convert Audio")
    }

    private var canConvert: Bool {
        sourceURL != nil && !isConverting && isVideoSettingsValid
    }

    private var displayedConversionProgress: Double {
        let rawProgress = isConverting ? conversionProgress : 0
        // 시작 직후의 미세한 값은 0%로 취급해 초기 파란 게이지 노출을 막습니다.
        return rawProgress < 0.01 ? 0 : rawProgress
    }

    private var progressTintColor: Color {
        displayedConversionProgress > 0 ? .accentColor : .clear
    }

    private var progressPercentageText: String {
        let percent = Int((displayedConversionProgress * 100).rounded())
        return "\(max(0, min(percent, 100)))%"
    }

    private var isVideoSettingsValid: Bool {
        if selectedVideoBitRate == .custom {
            return normalizedCustomVideoBitRateKbps != nil
        }
        return true
    }

    private var normalizedCustomVideoBitRateKbps: Int? {
        let trimmed = customVideoBitRate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let sanitized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Int(sanitized), value > 0 else { return nil }
        return value
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
            videoEncoder: selectedVideoEncoder,
            resolution: selectedResolution,
            frameRate: selectedFrameRate,
            videoBitRateKbps: videoBitRateKbps,
            audioEncoder: selectedAudioEncoder,
            audioMode: selectedAudioMode,
            sampleRate: selectedSampleRate,
            audioBitRateKbps: selectedAudioBitRate.kbps
        )
    }

    private func startConversion() {
        Task {
            await convert()
        }
    }

    private var preferredImportTypes: [UTType] {
        let mkvType = UTType(filenameExtension: "mkv")
        return [mkvType, .movie].compactMap { $0 }
    }

    @MainActor
    private func prepareConversionStartState() {
        isConverting = true
        convertedURL = nil
        conversionProgress = 0
    }

    @MainActor
    private func applyConversionError(_ error: Error) {
        if let conversionError = error as? ConversionError {
            print("변환 실패: \(conversionError.debugInfo)")
        } else {
            print("변환 실패: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func convert() async {
        guard let sourceURL else {
            print("변환할 파일이 없습니다.")
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

        let outputDirectory = sourceURL.deletingLastPathComponent()

        let shouldStopOutputAccessing = outputDirectory.startAccessingSecurityScopedResource()
        defer {
            if shouldStopOutputAccessing {
                outputDirectory.stopAccessingSecurityScopedResource()
            }
        }

        do {
            defer { isConverting = false }

            try FileManager.default.createDirectory(
                at: outputDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let destinationURL = uniqueOutputURL(for: sourceURL, in: outputDirectory)
            let workingOutputURL = temporaryOutputURL(for: sourceURL)
            defer {
                if FileManager.default.fileExists(atPath: workingOutputURL.path) {
                    try? FileManager.default.removeItem(at: workingOutputURL)
                }
            }

            let output = try await convertMKVToMP4(
                inputURL: sourceURL,
                outputURL: workingOutputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: nil
            )
            convertedURL = try saveConvertedOutput(from: output, to: destinationURL)
            conversionProgress = 1
        } catch {
            applyConversionError(error)
        }
    }

    private func uniqueOutputURL(for sourceURL: URL, in outputDirectory: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var candidate = outputDirectory.appendingPathComponent("\(baseName).mp4")
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputDirectory.appendingPathComponent("\(baseName)_converted_\(index).mp4")
            index += 1
        }
        return candidate
    }

    private func temporaryOutputURL(for sourceURL: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)_working_\(UUID().uuidString).mp4")
    }

    private func saveConvertedOutput(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        if sourceURL.path == destinationURL.path {
            return destinationURL
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            do {
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                try? FileManager.default.removeItem(at: sourceURL)
                return destinationURL
            } catch {
                throw ConversionError.outputSaveFailed(destinationURL.path, error.localizedDescription)
            }
        }
    }

    @MainActor
    private func updateConversionProgress(_ rawProgress: Double) {
        conversionProgress = min(max(rawProgress, 0), 1)
    }

    private func convertMKVToMP4(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?
    ) async throws -> URL {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        #if os(macOS)
        if try await convertWithFFmpegIfAvailable(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds
        ) {
            return outputURL
        }
        #endif

        let asset = AVURLAsset(url: inputURL)
        do {
            try await ensureAssetReadable(asset)
        } catch {
            if isUnsupportedMediaFormatError(error) {
                #if os(macOS)
                if try await convertWithFFmpegIfAvailable(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: inputDurationSeconds
                ) {
                    return outputURL
                }
                throw ConversionError.ffmpegUnavailable
                #endif
            }
            throw error
        }

        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let preferredPresets = [
            AVAssetExportPresetPassthrough,
            AVAssetExportPresetHighestQuality,
            AVAssetExportPresetMediumQuality,
            AVAssetExportPresetLowQuality
        ]
        let candidatePresets = preferredPresets.filter { compatiblePresets.contains($0) }

        guard !candidatePresets.isEmpty else {
            #if os(macOS)
            if try await convertWithFFmpegIfAvailable(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds
            ) {
                return outputURL
            }
            throw ConversionError.ffmpegUnavailable
            #else
            throw ConversionError.noCompatiblePreset(compatiblePresets)
            #endif
        }

        var lastError: Error?
        for preset in candidatePresets {
            guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
                lastError = ConversionError.cannotCreateExportSession(preset)
                continue
            }

            guard session.supportedFileTypes.contains(.mp4) else {
                lastError = ConversionError.unsupportedOutputType
                continue
            }

            session.outputURL = outputURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true

            let progressTask = Task {
                while !Task.isCancelled {
                    let status = session.status
                    if status != .waiting && status != .exporting {
                        break
                    }
                    updateConversionProgress(Double(session.progress))
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
            }

            do {
                try await export(session, preset: preset)
                progressTask.cancel()
                if session.status == .completed && FileManager.default.fileExists(atPath: outputURL.path) {
                    updateConversionProgress(1)
                    return outputURL
                }
                lastError = ConversionError.exportFailed(status: session.status, underlying: session.error, preset: preset)
            } catch {
                progressTask.cancel()
                lastError = error
                if isUnsupportedMediaFormatError(error) {
                    break
                }
            }
        }

        #if os(macOS)
        if let lastError, shouldFallbackToFFmpeg(after: lastError) {
            if try await convertWithFFmpegIfAvailable(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                inputDurationSeconds: inputDurationSeconds
            ) {
                return outputURL
            }

            if isUnsupportedMediaFormatError(lastError) {
                throw ConversionError.ffmpegUnavailable
            }
        }
        #endif

        throw lastError ?? ConversionError.unsupportedSource
    }

    #if os(macOS)
    private func convertWithFFmpegIfAvailable(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?
    ) async throws -> Bool {
        guard findFFmpegPath() != nil else {
            return false
        }

        try await convertMKVToMP4WithFFmpeg(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            inputDurationSeconds: inputDurationSeconds
        )
        return true
    }

    private func convertMKVToMP4WithFFmpeg(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        inputDurationSeconds: Double?
    ) async throws {
        guard let ffmpegPath = findFFmpegPath() else {
            throw ConversionError.ffmpegUnavailable
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        var lastError: Error?
        for codec in outputSettings.videoEncoder.codecCandidates {
            do {
                try await runFFmpeg(
                    ffmpegPath: ffmpegPath,
                    inputURL: inputURL,
                    outputURL: outputURL,
                    outputSettings: outputSettings,
                    videoCodec: codec,
                    inputDurationSeconds: inputDurationSeconds
                )
                return
            } catch {
                lastError = error
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try? FileManager.default.removeItem(at: outputURL)
                }
            }
        }

        throw lastError ?? ConversionError.ffmpegFailed(-1, "지원되는 비디오 인코더를 찾지 못했습니다.")
    }

    private func runFFmpeg(
        ffmpegPath: String,
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings,
        videoCodec: String,
        inputDurationSeconds: Double?
    ) async throws {
        var args = [
            "-y",
            "-progress", "pipe:1",
            "-nostats",
            "-i", inputURL.path,
            "-c:v", videoCodec
        ]

        if let dimensions = outputSettings.resolution.dimensions {
            args.append(contentsOf: ["-vf", "scale=\(dimensions.width):\(dimensions.height)"])
        }

        if let fps = outputSettings.frameRate.fps {
            args.append(contentsOf: ["-r", "\(fps)"])
        }

        if let videoBitRate = outputSettings.videoBitRateKbps {
            args.append(contentsOf: ["-b:v", "\(videoBitRate)k"])
        }

        if outputSettings.videoEncoder.isHEVC {
            args.append(contentsOf: ["-tag:v", "hvc1"])
        }

        args.append(contentsOf: [
            "-c:a", outputSettings.audioEncoder.codecName,
            "-ar", "\(outputSettings.sampleRate.hertz)"
        ])

        if let channels = outputSettings.audioMode.channelCount {
            args.append(contentsOf: ["-ac", "\(channels)"])
        }

        if let audioBitRate = outputSettings.audioBitRateKbps {
            args.append(contentsOf: ["-b:a", "\(audioBitRate)k"])
        }

        args.append(contentsOf: [
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            outputURL.path
        ])

        updateConversionProgress(0)

        var effectiveDuration = inputDurationSeconds
        let result = try await runCommand(path: ffmpegPath, arguments: args) { line in
            if effectiveDuration == nil {
                effectiveDuration = parseFFmpegDurationSeconds(from: line)
            }

            if line == "progress=end" {
                Task {
                    updateConversionProgress(1)
                }
                return
            }

            guard
                let outTimeSeconds = parseFFmpegOutTimeSeconds(from: line),
                let duration = effectiveDuration,
                duration > 0
            else {
                return
            }

            let ratio = outTimeSeconds / duration
            Task {
                updateConversionProgress(ratio)
            }
        }

        guard result.terminationStatus == 0 else {
            throw ConversionError.ffmpegFailed(
                result.terminationStatus,
                "[\(videoCodec)] \(result.output)"
            )
        }

        updateConversionProgress(1)
    }

    private func findFFmpegPath() -> String? {
        var candidates: [String] = []

        if let bundled = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            candidates.append(bundled)
        }
        if let resourcePath = Bundle.main.resourceURL?.path {
            candidates.append("\(resourcePath)/ffmpeg")
            candidates.append("\(resourcePath)/bin/ffmpeg")
        }
        if let executableDir = Bundle.main.executableURL?.deletingLastPathComponent().path {
            candidates.append("\(executableDir)/ffmpeg")
            candidates.append("\(executableDir)/bin/ffmpeg")
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ])
        if let fixed = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixed
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for directory in path.split(separator: ":") {
                let candidate = "\(directory)/ffmpeg"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        return nil
    }

    private func parseFFmpegDurationSeconds(from line: String) -> Double? {
        guard let markerRange = line.range(of: "Duration: ") else { return nil }
        let remaining = line[markerRange.upperBound...]
        guard let commaIndex = remaining.firstIndex(of: ",") else { return nil }
        let timestamp = String(remaining[..<commaIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return parseFFmpegTimestampSeconds(timestamp)
    }

    private func parseFFmpegOutTimeSeconds(from line: String) -> Double? {
        if line.hasPrefix("out_time=") {
            let value = String(line.dropFirst("out_time=".count))
            return parseFFmpegTimestampSeconds(value)
        }

        if line.hasPrefix("out_time_us=") {
            let raw = String(line.dropFirst("out_time_us=".count))
            guard let value = Double(raw) else { return nil }
            return value / 1_000_000
        }

        if line.hasPrefix("out_time_ms=") {
            let raw = String(line.dropFirst("out_time_ms=".count))
            guard let value = Double(raw) else { return nil }
            // ffmpeg -progress에서 out_time_ms는 실측상 microseconds 값을 반환합니다.
            return value / 1_000_000
        }

        return nil
    }

    private func parseFFmpegTimestampSeconds(_ timestamp: String) -> Double? {
        let normalized = timestamp
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let components = normalized.split(separator: ":")
        guard components.count == 3 else { return nil }
        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]) else {
            return nil
        }
        return (hours * 3600) + (minutes * 60) + seconds
    }

    private static func consumeCompleteLines(from buffer: inout Data) -> [String] {
        var lines: [String] = []
        let newline = Data([0x0A])

        while let range = buffer.range(of: newline) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            let text = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty {
                lines.append(text)
            }
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
        }

        return lines
    }

    private func runCommand(
        path: String,
        arguments: [String],
        outputLineHandler: ((String) -> Void)? = nil
    ) async throws -> (terminationStatus: Int32, output: String) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int32, String), Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            let outputHandle = outputPipe.fileHandleForReading
            let syncQueue = DispatchQueue(label: "myconverter.runcommand.output")
            var accumulated = Data()
            var lineBuffer = Data()

            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }

                syncQueue.async {
                    accumulated.append(data)
                    lineBuffer.append(data)
                    let lines = Self.consumeCompleteLines(from: &lineBuffer)
                    guard let outputLineHandler else { return }
                    for line in lines {
                        outputLineHandler(line)
                    }
                }
            }

            process.terminationHandler = { proc in
                outputHandle.readabilityHandler = nil
                let trailingData = outputHandle.readDataToEndOfFile()

                syncQueue.async {
                    if !trailingData.isEmpty {
                        accumulated.append(trailingData)
                        lineBuffer.append(trailingData)
                    }

                    let lines = Self.consumeCompleteLines(from: &lineBuffer)
                    if let outputLineHandler {
                        for line in lines {
                            outputLineHandler(line)
                        }

                        if !lineBuffer.isEmpty,
                           let trailingLine = String(data: lineBuffer, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !trailingLine.isEmpty {
                            outputLineHandler(trailingLine)
                        }
                    }

                    let output = String(data: accumulated, encoding: .utf8) ?? ""
                    continuation.resume(returning: (proc.terminationStatus, output))
                }
            }

            do {
                try process.run()
            } catch {
                outputHandle.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
    #endif

    private func shouldFallbackToFFmpeg(after error: Error) -> Bool {
        if let conversionError = error as? ConversionError {
            switch conversionError {
            case .invalidCustomVideoBitRate,
                    .exportCancelled,
                    .ffmpegUnavailable,
                    .ffmpegFailed:
                return false
            default:
                return true
            }
        }

        if isUnsupportedMediaFormatError(error) {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == AVFoundationErrorDomain || nsError.domain == NSOSStatusErrorDomain {
            return true
        }

        if error is AVError {
            return true
        }

        return false
    }

    private func isUnsupportedMediaFormatError(_ error: Error) -> Bool {
        if let conversionError = error as? ConversionError {
            if case let .exportFailed(_, underlying: underlying, _) = conversionError {
                if let underlying {
                    return isUnsupportedMediaFormatError(underlying)
                }
            }
            if case .unreadableAsset = conversionError {
                return true
            }
            if case .ffmpegFailed = conversionError {
                return false
            }
            return false
        }

        if let avError = error as? AVError {
            return avError.code == .fileFormatNotRecognized ||
                avError.code == .decoderNotFound
        }

        let nsError = error as NSError
        if nsError.domain == AVFoundationErrorDomain {
            if nsError.code == -11828 ||
                nsError.code == AVError.fileFormatNotRecognized.rawValue ||
                nsError.code == AVError.decoderNotFound.rawValue {
                return true
            }

            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                return isUnsupportedMediaFormatError(underlying)
            }

            if let dependencies = nsError.userInfo["AVErrorFailedDependenciesKey"] as? [Any],
               dependencies.contains(where: { item in
                guard let depError = item as? Error else { return false }
                return isUnsupportedMediaFormatError(depError)
            }) {
                return true
            }
        }

        if nsError.domain == NSOSStatusErrorDomain && (nsError.code == -12847 || nsError.code == -12894) {
            return true
        }

        return false
    }

    private func ensureAssetReadable(_ asset: AVURLAsset) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let keys = ["tracks", "playable", "duration"]
            asset.loadValuesAsynchronously(forKeys: keys) {
                for key in keys {
                    var keyError: NSError?
                    let status = asset.statusOfValue(forKey: key, error: &keyError)
                    if status == .failed || status == .cancelled {
                        continuation.resume(
                            throwing: keyError ?? ConversionError.unreadableAsset
                        )
                        return
                    }
                    if status != .loaded {
                        continuation.resume(
                            throwing: ConversionError.unreadableAsset
                        )
                        return
                    }
                }

                let hasMediaTrack = !(asset.tracks(withMediaType: .video).isEmpty &&
                                      asset.tracks(withMediaType: .audio).isEmpty)
                if !hasMediaTrack {
                    continuation.resume(throwing: ConversionError.noTracksFound)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private func export(_ session: AVAssetExportSession, preset: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume(returning: ())
                case .cancelled:
                    continuation.resume(throwing: ConversionError.exportCancelled)
                case .failed:
                    continuation.resume(
                        throwing: ConversionError.exportFailed(
                            status: session.status,
                            underlying: session.error,
                            preset: preset
                        )
                    )
                default:
                    continuation.resume(
                        throwing: ConversionError.exportFailed(
                            status: session.status,
                            underlying: session.error,
                            preset: preset
                        )
                    )
                }
            }
        }
    }
}

private enum ConversionError: LocalizedError {
    case unsupportedSource
    case unreadableAsset
    case noTracksFound
    case invalidCustomVideoBitRate(String)
    case noCompatiblePreset([String])
    case cannotCreateExportSession(String)
    case unsupportedOutputType
    case exportCancelled
    case exportFailed(status: AVAssetExportSession.Status, underlying: Error?, preset: String)
    case ffmpegUnavailable
    case ffmpegFailed(Int32, String)
    case outputSaveFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "입력 파일을 읽지 못했습니다."
        case .unreadableAsset:
            return "MKV 파일을 해석할 수 없습니다."
        case .noTracksFound:
            return "동영상/오디오 트랙을 찾지 못했습니다."
        case .invalidCustomVideoBitRate:
            return "Custom Video Bit Rate는 1 이상의 정수(Kbps)여야 합니다."
        case .noCompatiblePreset:
            return "현재 AVFoundation에서 지원 가능한 변환 프리셋이 없습니다."
        case .cannotCreateExportSession:
            return "변환 세션을 만들 수 없습니다."
        case .unsupportedOutputType:
            return "이 장치에서는 MP4 출력이 지원되지 않습니다."
        case .exportCancelled:
            return "변환이 중단되었습니다."
        case .ffmpegUnavailable:
            return "이 MKV는 AVFoundation에서 열 수 없습니다. ffmpeg를 찾지 못했습니다."
        case .ffmpegFailed(_, let output):
            if output.localizedCaseInsensitiveContains("operation not permitted") ||
                output.localizedCaseInsensitiveContains("permission denied") {
                return "입력 파일 폴더에 쓸 수 없습니다. 폴더 권한을 확인해 주세요."
            }
            return "ffmpeg 변환이 실패했습니다."
        case .outputSaveFailed:
            return "변환 파일 저장에 실패했습니다. 입력 파일 폴더 권한을 확인해 주세요."
        case .exportFailed:
            return "AVAssetExportSession 변환에 실패했습니다."
        }
    }

    var debugInfo: String {
        switch self {
        case .noCompatiblePreset(let presets):
            return "지원 프리셋: \(presets.joined(separator: ", "))"
        case .cannotCreateExportSession(let preset):
            return "프리셋 \(preset)로 세션 생성 실패"
        case .unsupportedOutputType:
            return "outputFileType으로 .mp4를 허용하지 않습니다."
        case .exportFailed(let status, let underlying, let preset):
            if let underlying {
                return "프리셋: \(preset), 상태: \(status), 상세: \(underlying.localizedDescription)"
            }
            return "프리셋: \(preset), 상태: \(status)"
        case .exportCancelled:
            return "상태: cancelled"
        case .ffmpegUnavailable:
            return "brew install ffmpeg 또는 앱 번들에 ffmpeg를 포함해 주세요."
        case .ffmpegFailed(let code, let output):
            return "FFmpeg 종료 코드: \(code). 상세: \(output)"
        case .outputSaveFailed(let path, let reason):
            return "저장 경로: \(path), 상세: \(reason)"
        case .invalidCustomVideoBitRate(let value):
            return "입력값: \(value)"
        case .unreadableAsset:
            return "MKV 파서를 읽지 못했습니다(코덱 미지원일 수 있음)."
        case .unsupportedSource:
            return "지원되지 않는 MKV 코덱/컨테이너 가능성."
        case .noTracksFound:
            return "비디오/오디오 트랙 미탐지."
        }
    }
}

#Preview {
    ContentView()
}
