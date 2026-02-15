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
