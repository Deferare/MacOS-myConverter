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
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedTab) {
                ForEach(ConverterTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("MyConverter")
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            switch viewModel.selectedTab {
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
            if viewModel.selectedTab == .video {
                Button {
                    viewModel.startConversion()
                } label: {
                    Label("Convert", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                }
                .disabled(!viewModel.canConvert)
            }
        }
        .frame(minWidth: 980, minHeight: 620)
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: viewModel.preferredImportTypes,
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileImportResult(result)
        }
    }

    private var videoDetailView: some View {
        VStack(spacing: 0) {
            Group {
                if let sourceURL = viewModel.sourceURL {
                    SelectedFileView(url: sourceURL) {
                        withAnimation {
                            viewModel.clearSelectedSource()
                        }
                    }
                } else {
                    DropFileView {
                        viewModel.requestFileImport()
                    }
                }
            }
            .padding(20)

            Divider()

            Form {
                Section("Output Settings") {
                    Picker("Container", selection: $viewModel.selectedOutputFormat) {
                        ForEach(viewModel.outputFormatOptions) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.outputFormatOptions.isEmpty)

                    Picker("Video Encoder", selection: $viewModel.selectedVideoEncoder) {
                        ForEach(VideoEncoderOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Resolution", selection: $viewModel.selectedResolution) {
                        ForEach(ResolutionOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Frame Rate", selection: $viewModel.selectedFrameRate) {
                        ForEach(FrameRateOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Video Bit Rate", selection: $viewModel.selectedVideoBitRate) {
                        ForEach(VideoBitRateOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    if viewModel.selectedVideoBitRate == .custom {
                        TextField("Custom Kbps (e.g. 5000)", text: $viewModel.customVideoBitRate)
                            .textFieldStyle(.roundedBorder)
                    }

                    Picker("Audio Encoder", selection: $viewModel.selectedAudioEncoder) {
                        ForEach(AudioEncoderOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Audio Mode", selection: $viewModel.selectedAudioMode) {
                        ForEach(AudioModeOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Sample Rate", selection: $viewModel.selectedSampleRate) {
                        ForEach(SampleRateOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Audio Bit Rate", selection: $viewModel.selectedAudioBitRate) {
                        ForEach(AudioBitRateOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    if viewModel.isAnalyzingSource {
                        Text("Analyzing source compatibility...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let warning = viewModel.sourceCompatibilityWarningMessage {
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    if let validation = viewModel.videoSettingsValidationMessage {
                        Text(validation)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Output File") {
                    if let convertedURL = viewModel.convertedURL {
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

                    if let conversionErrorMessage = viewModel.conversionErrorMessage {
                        Text(conversionErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
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
            viewModel.handleDrop(providers: providers)
        }
    }

    private var videoConversionControls: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.startConversion()
            } label: {
                Label(
                    viewModel.isConverting ? "Converting..." : "Start Conversion",
                    systemImage: viewModel.isConverting ? "arrow.triangle.2.circlepath" : "play.fill"
                )
                .font(.body.bold())
                .frame(minWidth: 120, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canConvert)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: viewModel.displayedConversionProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(progressTintColor)

                HStack {
                    Text(viewModel.isConverting ? "Conversion in progress..." : "Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(viewModel.progressPercentageText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var progressTintColor: Color {
        viewModel.displayedConversionProgress > 0 ? .accentColor : .clear
    }

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

                    Text("or click to select any video file")
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
                viewModel.requestFileImport()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isConverting)

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isConverting)
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
}

#Preview {
    ContentView()
}
