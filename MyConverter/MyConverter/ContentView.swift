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
                return ["libx265", "hevc"]
            case .h265GPU:
                return ["hevc_videotoolbox"]
            case .h264CPU:
                return ["libx264", "h264"]
            case .h264GPU:
                return ["h264_videotoolbox"]
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

        var codecName: String {
            switch self {
            case .aac:
                return "aac"
            }
        }
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

        var shouldUseDirectFFmpeg: Bool {
            videoEncoder != .h264GPU ||
                resolution != .original ||
                frameRate != .original ||
                videoBitRateKbps != nil ||
                audioMode != .auto ||
                sampleRate != .hz48000 ||
                audioBitRateKbps != nil
        }
    }

    @State private var sourceURL: URL?
    @State private var convertedURL: URL?
    @State private var isImporting = false
    @State private var isConverting = false
    @State private var statusMessage = "MKV 파일을 선택해 MP4로 변환하세요."
    @State private var errorMessage: String?
    @State private var debugMessage: String?
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
                errorMessage = nil
                debugMessage = nil
                statusMessage = "선택됨: \(selected.lastPathComponent)"
            case .failure(let error):
                errorMessage = error.localizedDescription
                statusMessage = "파일 선택에 실패했습니다."
            }
        }
    }

    private var videoDetailView: some View {
        Form {
            Section("입력 파일") {
                Button {
                    isImporting = true
                } label: {
                    Label(sourceURL == nil ? "MKV 파일 선택" : "다른 MKV 선택", systemImage: "doc")
                }
                .disabled(isConverting)

                if let sourceURL {
                    LabeledContent("파일명") {
                        Text(sourceURL.lastPathComponent)
                            .textSelection(.enabled)
                    }

                    LabeledContent("위치") {
                        Text(sourceURL.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                } else {
                    Text("아직 선택된 입력 파일이 없습니다.")
                        .foregroundStyle(.secondary)
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

                Text("고급 출력 옵션이 설정되면 ffmpeg 인코딩으로 변환합니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("실행") {
                Button {
                    startConversion()
                } label: {
                    Label(isConverting ? "변환 중..." : "MP4로 변환", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canConvert)

                if isConverting {
                    ProgressView("파일 변환 중")
                        .progressViewStyle(.linear)
                }

                LabeledContent("현재 상태") {
                    Text(statusMessage)
                        .foregroundStyle(statusColor)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        .navigationTitle("Convert Video")
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

    private var statusColor: Color {
        if errorMessage != nil {
            return .red
        }
        if isConverting {
            return .orange
        }
        if convertedURL != nil {
            return .green
        }
        return .secondary
    }

    private var statusIcon: String {
        if errorMessage != nil {
            return "exclamationmark.triangle.fill"
        }
        if isConverting {
            return "hourglass"
        }
        if convertedURL != nil {
            return "checkmark.circle.fill"
        }
        return "info.circle"
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

    private func convert() async {
        guard let sourceURL else {
            errorMessage = "변환할 파일이 없습니다."
            return
        }

        let outputSettings: VideoOutputSettings
        do {
            outputSettings = try buildVideoOutputSettings()
        } catch {
            errorMessage = error.localizedDescription
            if let conversionError = error as? ConversionError {
                debugMessage = conversionError.debugInfo
            } else {
                debugMessage = "상세: \(error)"
            }
            statusMessage = "출력 설정 오류"
            return
        }

        isConverting = true
        statusMessage = "변환 중..."
        errorMessage = nil
        debugMessage = nil
        convertedURL = nil

        let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            defer { isConverting = false }
            let destinationURL = uniqueOutputURL(for: sourceURL)
            let output = try await convertMKVToMP4(
                inputURL: sourceURL,
                outputURL: destinationURL,
                outputSettings: outputSettings
            )
            convertedURL = output
            statusMessage = "변환 완료"
        } catch {
            isConverting = false
            errorMessage = error.localizedDescription
            if let conversionError = error as? ConversionError {
                debugMessage = conversionError.debugInfo
            } else {
                debugMessage = "상세: \(error)"
            }
            statusMessage = "변환 실패"
        }
    }

    private func uniqueOutputURL(for sourceURL: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outputDirectory = FileManager.default.temporaryDirectory
        var candidate = outputDirectory.appendingPathComponent("\(baseName).mp4")
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputDirectory.appendingPathComponent("\(baseName)_converted_\(index).mp4")
            index += 1
        }
        return candidate
    }

    private func convertMKVToMP4(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings
    ) async throws -> URL {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        #if os(macOS)
        if outputSettings.shouldUseDirectFFmpeg {
            try await convertMKVToMP4WithFFmpeg(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings
            )
            return outputURL
        }
        #endif

        let asset = AVURLAsset(url: inputURL)
        do {
            try await ensureAssetReadable(asset)
        } catch {
            if isUnsupportedMediaFormatError(error) {
                #if os(macOS)
                if findFFmpegPath() != nil {
                    try await convertMKVToMP4WithFFmpeg(
                        inputURL: inputURL,
                        outputURL: outputURL,
                        outputSettings: outputSettings
                    )
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
            if findFFmpegPath() != nil {
                try await convertMKVToMP4WithFFmpeg(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    outputSettings: outputSettings
                )
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

            do {
                try await export(session, preset: preset)
                if session.status == .completed && FileManager.default.fileExists(atPath: outputURL.path) {
                    return outputURL
                }
                lastError = ConversionError.exportFailed(status: session.status, underlying: session.error, preset: preset)
            } catch {
                lastError = error
                if isUnsupportedMediaFormatError(error) {
                    break
                }
            }
        }

        #if os(macOS)
        if let lastError, isUnsupportedMediaFormatError(lastError) {
            do {
                try await convertMKVToMP4WithFFmpeg(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    outputSettings: outputSettings
                )
                return outputURL
            } catch {
                if case ConversionError.ffmpegUnavailable = error {
                    throw error
                }
                throw error
            }
        }
        #endif

        #if os(macOS)
        if let lastError, isUnsupportedMediaFormatError(lastError), findFFmpegPath() == nil {
            throw ConversionError.ffmpegUnavailable
        }
        #endif

        throw lastError ?? ConversionError.unsupportedSource
    }

    #if os(macOS)
    private func convertMKVToMP4WithFFmpeg(
        inputURL: URL,
        outputURL: URL,
        outputSettings: VideoOutputSettings
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
                    videoCodec: codec
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
        videoCodec: String
    ) async throws {
        var args = [
            "-y",
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

        let result = try await runCommand(path: ffmpegPath, arguments: args)
        guard result.terminationStatus == 0 else {
            throw ConversionError.ffmpegFailed(
                result.terminationStatus,
                "[\(videoCodec)] \(result.output)"
            )
        }
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

    private func runCommand(path: String, arguments: [String]) async throws -> (terminationStatus: Int32, output: String) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int32, String), Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            process.terminationHandler = { proc in
                let data = try? outputPipe.fileHandleForReading.readToEnd() ?? Data()
                let output = String(data: data ?? Data(), encoding: .utf8) ?? ""
                continuation.resume(returning: (proc.terminationStatus, output))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    #endif

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

        if nsError.domain == NSOSStatusErrorDomain && nsError.code == -12847 {
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
        case .ffmpegFailed:
            return "ffmpeg 변환이 실패했습니다."
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
