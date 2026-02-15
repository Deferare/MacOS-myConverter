//
//  ContentView.swift
//  MyConverter
//
//  Created by JiHoon K on 2/14/26.
//

import SwiftUI
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
                    Label("Convert", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
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
                print("Failed to select file: \(error.localizedDescription)")
            }
        }
    }

    private var videoDetailView: some View {
        VStack(spacing: 0) {
            // Input File Area (Drag & Drop)
            Group {
                if let sourceURL {
                    SelectedFileView(url: sourceURL) {
                        withAnimation {
                            self.sourceURL = nil
                            self.convertedURL = nil
                        }
                    }
                } else {
                    DropFileView {
                        isImporting = true
                    }
                }
            }
            .padding(20)
            
            Divider()
            
            // Settings Form
            Form {
                Section("Output Settings") {
                    LabeledContent("Container") { Text("MP4").fontWeight(.semibold) }

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
                        TextField("Custom Kbps (e.g. 5000)", text: $customVideoBitRate)
                            .textFieldStyle(.roundedBorder)

                        if normalizedCustomVideoBitRateKbps == nil {
                            Text("Please enter an integer greater than 1 for Custom Bitrate (Kbps).")
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

                Section("Output File") {
                    if let convertedURL {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Conversion Successful!")
                                    .font(.headline)
                            }
                            
                            LabeledContent("File Name") {
                                Text(convertedURL.lastPathComponent)
                                    .textSelection(.enabled)
                            }

                            LabeledContent("Location") {
                                Text(convertedURL.path)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 12) {
                                ShareLink(item: convertedURL) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                                
                                #if os(macOS)
                                Button {
                                    NSWorkspace.shared.open(convertedURL.deletingLastPathComponent())
                                } label: {
                                    Label("Open Folder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                                
                                Button {
                                    NSWorkspace.shared.open(convertedURL)
                                } label: {
                                    Label("Open File", systemImage: "play.rectangle")
                                }
                                .buttonStyle(.borderedProminent)
                                #endif
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("The converted file will appear here.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .safeAreaInset(edge: .bottom) {
            videoConversionControls
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.regularMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .top)
        }
        .navigationTitle("Convert Video")
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private var videoConversionControls: some View {
        HStack(spacing: 16) {
            Button {
                startConversion()
            } label: {
                Label(
                    isConverting ? "Converting..." : "Start Conversion",
                    systemImage: isConverting ? "arrow.triangle.2.circlepath" : "play.fill"
                )
                .font(.body.bold())
                .frame(minWidth: 120, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canConvert)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: displayedConversionProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(progressTintColor)
                
                HStack {
                    Text(isConverting ? "Conversion in progress..." : "Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(progressPercentageText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - UI Subviews (ViewBuilders) in ContentView
    
    private func DropFileView(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.primary)
                }
                
                VStack(spacing: 6) {
                    Text("Drop file here")
                        .font(.title3.bold())
                    
                    Text("or click to select MKV file")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .background(Color.secondary.opacity(0.05))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func SelectedFileView(url: URL, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor)
                    .frame(width: 50, height: 60)
                
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Button("Change") {
                isImporting = true
            }
            .buttonStyle(.bordered)
            .disabled(isConverting)
            
            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .disabled(isConverting)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var finalURL: URL?
            
            if let data = item as? Data {
                finalURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                finalURL = url
            }
            
            if let url = finalURL {
                Task { @MainActor in
                    withAnimation {
                        // 간단한 확장자 체크
                        let ext = url.pathExtension.lowercased()
                        if ext == "mkv" || ext == "mov" || ext == "mp4" {
                            self.sourceURL = url
                            self.convertedURL = nil
                        }
                    }
                }
            }
        }
        return true
    }

    private var imageDetailView: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "Image Conversion Coming Soon",
                systemImage: "photo.badge.arrow.down",
                description: Text("This feature will be available soon.")
            )
        }
        .navigationTitle("Convert Image")
    }

    private var audioDetailView: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "Audio Conversion Coming Soon",
                systemImage: "waveform.badge.magnifyingglass",
                description: Text("This feature will be available soon.")
            )
        }
        .navigationTitle("Convert Audio")
    }

    private var canConvert: Bool {
        sourceURL != nil && !isConverting && isVideoSettingsValid
    }

    private var displayedConversionProgress: Double {
        let rawProgress = isConverting ? conversionProgress : 0
        // Treat minute values immediately after start as 0% to prevent initial blue gauge flash.
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
            print("Conversion failed: \(conversionError.debugInfo)")
        } else {
            print("Conversion failed: \(error.localizedDescription)")
        }
    }

    @MainActor
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
            ) { progress in
                await updateConversionProgress(progress)
            }
            convertedURL = try VideoConversionEngine.saveConvertedOutput(from: output, to: destinationURL)
            conversionProgress = 1
        } catch {
            applyConversionError(error)
        }
    }

    @MainActor
    private func updateConversionProgress(_ rawProgress: Double) {
        conversionProgress = min(max(rawProgress, 0), 1)
    }

}

#Preview {
    ContentView()
}
