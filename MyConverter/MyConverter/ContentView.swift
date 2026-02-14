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
                LabeledContent("비디오") { Text("H.264 (VideoToolbox 우선)") }
                LabeledContent("오디오") { Text("AAC") }
                Text("일부 MKV는 AVFoundation 미지원일 수 있으며, 이 경우 ffmpeg로 자동 대체합니다.")
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
        sourceURL != nil && !isConverting
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
            let output = try await convertMKVToMP4(inputURL: sourceURL, outputURL: destinationURL)
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

    private func convertMKVToMP4(inputURL: URL, outputURL: URL) async throws -> URL {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let asset = AVURLAsset(url: inputURL)
        do {
            try await ensureAssetReadable(asset)
        } catch {
            if isUnsupportedMediaFormatError(error) {
                #if os(macOS)
                if findFFmpegPath() != nil {
                    try await convertMKVToMP4WithFFmpeg(inputURL: inputURL, outputURL: outputURL)
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
                try await convertMKVToMP4WithFFmpeg(inputURL: inputURL, outputURL: outputURL)
                return outputURL
            }
            throw ConversionError.ffmpegUnavailable
            #endif

            throw ConversionError.noCompatiblePreset(compatiblePresets)
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
                try await convertMKVToMP4WithFFmpeg(inputURL: inputURL, outputURL: outputURL)
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
    private func convertMKVToMP4WithFFmpeg(inputURL: URL, outputURL: URL) async throws {
        guard let ffmpegPath = findFFmpegPath() else {
            throw ConversionError.ffmpegUnavailable
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        do {
            try await runFFmpeg(ffmpegPath: ffmpegPath, inputURL: inputURL, outputURL: outputURL, mode: .h264VideoToolbox)
            return
        } catch {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
        }

        try await runFFmpeg(ffmpegPath: ffmpegPath, inputURL: inputURL, outputURL: outputURL, mode: .mpeg4Aac)
    }

    private enum FFmpegMode: String {
        case h264VideoToolbox = "h264-videotoolbox"
        case mpeg4Aac = "mpeg4-aac"
    }

    private func runFFmpeg(ffmpegPath: String, inputURL: URL, outputURL: URL, mode: FFmpegMode) async throws {
        let args: [String]
        switch mode {
        case .h264VideoToolbox:
            args = [
                "-y",
                "-i", inputURL.path,
                "-c:v", "h264_videotoolbox",
                "-c:a", "aac",
                "-b:a", "192k",
                "-pix_fmt", "yuv420p",
                "-movflags", "+faststart",
                outputURL.path
            ]
        case .mpeg4Aac:
            args = [
                "-y",
                "-i", inputURL.path,
                "-c:v", "mpeg4",
                "-q:v", "4",
                "-c:a", "aac",
                "-b:a", "192k",
                "-movflags", "+faststart",
                outputURL.path
            ]
        }

        let result = try await runCommand(path: ffmpegPath, arguments: args)
        guard result.terminationStatus == 0 else {
            throw ConversionError.ffmpegFailed(
                result.terminationStatus,
                "[\(mode.rawValue)] \(result.output)"
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
