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
    @State private var selectedTab: ConverterTab = .video
    @State private var isVideoDropTargeted = false
    @State private var isImageDropTargeted = false
    @State private var isAudioDropTargeted = false
    @State private var isShowingOpenSourceLicenses = false

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
            case .about:
                aboutDetailView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 980, minHeight: 620)
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: viewModel.preferredImportTypes(for: selectedTab),
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileImportResult(result, for: selectedTab)
        }
    }

    private var videoDetailView: some View {
        VStack(spacing: 0) {
            Group {
                if !isVideoDropTargeted, let sourceURL = viewModel.sourceURL {
                    SelectedFileView(
                        url: sourceURL,
                        systemImage: "film.fill",
                        isConverting: viewModel.isConverting
                    ) {
                        withAnimation {
                            viewModel.clearSelectedVideoSource()
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    DropFileView(
                        isDropTargeted: isVideoDropTargeted,
                        placeholder: "Drop Video Here"
                    ) {
                        viewModel.requestFileImport()
                    }
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.sourceURL)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVideoDropTargeted)
            .padding(20)

            Divider()

            Form {
                Section("Output Settings") {
                    Picker("Container", selection: $viewModel.selectedOutputFormat) {
                        ForEach(viewModel.outputFormatOptions) { format in
                            Text("\(format.displayName) (.\(format.fileExtension))").tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.outputFormatOptions.isEmpty)

                    if viewModel.shouldShowVideoEncoderOption {
                        Picker("Video Encoder", selection: $viewModel.selectedVideoEncoder) {
                            ForEach(viewModel.videoEncoderOptions) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.videoEncoderOptions.isEmpty)
                    }

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

                    if viewModel.shouldShowGIFPlaybackSpeedOption {
                        Picker("Playback Speed", selection: $viewModel.selectedGIFPlaybackSpeed) {
                            ForEach(GIFPlaybackSpeedOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if viewModel.shouldShowVideoBitRateOption {
                        Picker("Video Bit Rate", selection: $viewModel.selectedVideoBitRate) {
                            ForEach(VideoBitRateOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if viewModel.shouldShowVideoBitRateOption && viewModel.selectedVideoBitRate == .custom {
                        TextField("Custom Kbps (e.g. 5000)", text: $viewModel.customVideoBitRate)
                            .textFieldStyle(.roundedBorder)
                    }

                    if viewModel.shouldShowAudioSettings {
                        Picker("Audio Encoder", selection: $viewModel.selectedAudioEncoder) {
                            ForEach(viewModel.audioEncoderOptions) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(viewModel.audioEncoderOptions.isEmpty)

                        Picker("Audio Mode", selection: $viewModel.selectedAudioMode) {
                            ForEach(AudioModeOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)

                        if viewModel.shouldShowAudioSampleRateOption {
                            Picker("Sample Rate", selection: $viewModel.selectedSampleRate) {
                                ForEach(SampleRateOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        if viewModel.shouldShowAudioBitRateOption {
                            Picker("Audio Bit Rate", selection: $viewModel.selectedAudioBitRate) {
                                ForEach(AudioBitRateOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                Section("Output File") {
                    if let convertedURL = viewModel.convertedURL {
                        ConversionResultView(
                            url: convertedURL,
                            detailText: "Your video is ready to view",
                            openSystemImage: "play.fill"
                        )
                        .padding(.vertical, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        Text("The converted file will appear here")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
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
        .onDrop(of: [.fileURL], isTargeted: $isVideoDropTargeted) { providers in
            viewModel.handleVideoDrop(providers: providers)
        }
    }

    private var imageDetailView: some View {
        VStack(spacing: 0) {
            Group {
                if !isImageDropTargeted, let sourceURL = viewModel.imageSourceURL {
                    SelectedFileView(
                        url: sourceURL,
                        systemImage: "photo.fill",
                        isConverting: viewModel.isImageConverting
                    ) {
                        withAnimation {
                            viewModel.clearSelectedImageSource()
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    DropFileView(
                        isDropTargeted: isImageDropTargeted,
                        placeholder: "Drop Image Here"
                    ) {
                        viewModel.requestFileImport()
                    }
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.imageSourceURL)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isImageDropTargeted)
            .padding(20)

            Divider()

            Form {
                Section("Output Settings") {
                    Picker("Container", selection: $viewModel.selectedImageOutputFormat) {
                        ForEach(viewModel.imageOutputFormatOptions) { format in
                            Text("\(format.displayName) (.\(format.fileExtension))").tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.imageOutputFormatOptions.isEmpty)

                    Picker("Resolution", selection: $viewModel.selectedImageResolution) {
                        ForEach(ResolutionOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    if viewModel.shouldShowImageQualityOption {
                        Picker("Quality", selection: $viewModel.selectedImageQuality) {
                            ForEach(ImageQualityOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if viewModel.shouldShowPNGCompressionOption {
                        Picker("PNG Compression", selection: $viewModel.selectedPNGCompressionLevel) {
                            ForEach(PNGCompressionLevelOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if viewModel.shouldShowPreserveAnimationOption {
                        Toggle("Preserve Animation", isOn: $viewModel.preserveImageAnimation)
                    }

                    if let hint = viewModel.imageFormatHintMessage {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Output File") {
                    if let convertedURL = viewModel.convertedImageURL {
                        ConversionResultView(
                            url: convertedURL,
                            detailText: "Your image is ready to view",
                            openSystemImage: "photo.fill"
                        )
                        .padding(.vertical, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        Text("The converted file will appear here")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .safeAreaInset(edge: .bottom) {
            imageConversionControls
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.regularMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .top)
        }
        .navigationTitle("Convert Image")
        .onDrop(of: [.fileURL], isTargeted: $isImageDropTargeted) { providers in
            viewModel.handleImageDrop(providers: providers)
        }
    }

    private var videoConversionControls: some View {
        HStack(spacing: 16) {
            Button {
                if viewModel.isConverting {
                    viewModel.cancelConversion()
                } else {
                    viewModel.startConversion()
                }
            } label: {
                Label(
                    viewModel.isConverting ? "Cancel" : "Start Conversion",
                    systemImage: viewModel.isConverting ? "xmark.circle.fill" : "play.fill"
                )
                .font(.body.bold())
                .frame(minWidth: 120, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isConverting ? false : !viewModel.canConvert)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: viewModel.displayedConversionProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(videoProgressTintColor)

                HStack {
                    Text(viewModel.conversionStatusMessage)
                        .font(.caption)
                        .foregroundStyle(videoConversionStatusColor)
                        .lineLimit(1)

                    Spacer()

                    Text(viewModel.progressPercentageText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var imageConversionControls: some View {
        HStack(spacing: 16) {
            Button {
                if viewModel.isImageConverting {
                    viewModel.cancelImageConversion()
                } else {
                    viewModel.startImageConversion()
                }
            } label: {
                Label(
                    viewModel.isImageConverting ? "Cancel" : "Start Conversion",
                    systemImage: viewModel.isImageConverting ? "xmark.circle.fill" : "play.fill"
                )
                .font(.body.bold())
                .frame(minWidth: 120, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isImageConverting ? false : !viewModel.canConvertImage)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: viewModel.displayedImageConversionProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(imageProgressTintColor)

                HStack {
                    Text(viewModel.imageConversionStatusMessage)
                        .font(.caption)
                        .foregroundStyle(imageConversionStatusColor)
                        .lineLimit(1)

                    Spacer()

                    Text(viewModel.imageProgressPercentageText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var audioConversionControls: some View {
        HStack(spacing: 16) {
            Button {
                if viewModel.isAudioConverting {
                    viewModel.cancelAudioConversion()
                } else {
                    viewModel.startAudioConversion()
                }
            } label: {
                Label(
                    viewModel.isAudioConverting ? "Cancel" : "Start Conversion",
                    systemImage: viewModel.isAudioConverting ? "xmark.circle.fill" : "play.fill"
                )
                .font(.body.bold())
                .frame(minWidth: 120, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isAudioConverting ? false : !viewModel.canConvertAudio)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: viewModel.displayedAudioConversionProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(audioProgressTintColor)

                HStack {
                    Text(viewModel.audioConversionStatusMessage)
                        .font(.caption)
                        .foregroundStyle(audioConversionStatusColor)
                        .lineLimit(1)

                    Spacer()

                    Text(viewModel.audioProgressPercentageText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var videoProgressTintColor: Color {
        viewModel.displayedConversionProgress > 0 ? .accentColor : .clear
    }

    private var imageProgressTintColor: Color {
        viewModel.displayedImageConversionProgress > 0 ? .accentColor : .clear
    }

    private var audioProgressTintColor: Color {
        viewModel.displayedAudioConversionProgress > 0 ? .accentColor : .clear
    }

    private var videoConversionStatusColor: Color {
        statusColor(for: viewModel.conversionStatusLevel)
    }

    private var imageConversionStatusColor: Color {
        statusColor(for: viewModel.imageConversionStatusLevel)
    }

    private var audioConversionStatusColor: Color {
        statusColor(for: viewModel.audioConversionStatusLevel)
    }

    private func statusColor(for level: ContentViewModel.ConversionStatusLevel) -> Color {
        switch level {
        case .normal:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func DropFileView(
        isDropTargeted: Bool,
        placeholder: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.15) : Color.accentColor.opacity(0.05))
                        .frame(width: 90, height: 90)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTargeted)

                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .primary)
                        .scaleEffect(isDropTargeted ? 1.15 : 1.0)
                        .rotationEffect(.degrees(isDropTargeted ? 10 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTargeted)
                }

                VStack(spacing: 8) {
                    Text(isDropTargeted ? "Release to Import" : placeholder)
                        .font(.title3.bold())
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .primary)
                        .scaleEffect(isDropTargeted ? 1.05 : 1.0)

                    Text(isDropTargeted ? "Ready to load your file" : "or click to browse local files")
                        .font(.body)
                        .foregroundStyle(isDropTargeted ? Color.secondary.opacity(0.8) : Color.secondary)
                }
                .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.04) : Color(nsColor: .controlBackgroundColor).opacity(0.5))

                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 3 : 1, dash: isDropTargeted ? [] : [10])
                        )
                }
            )
            .contentShape(Rectangle())
            .scaleEffect(isDropTargeted ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTargeted)
        }
        .buttonStyle(.plain)
    }

    private func SelectedFileView(
        url: URL,
        systemImage: String,
        isConverting: Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 72)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)

                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Change") {
                    viewModel.requestFileImport()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isConverting)

                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.secondary.opacity(0.8))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isConverting)
                .onHover { inside in
                    if inside {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardBackgroundColor)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func ConversionResultView(
        url: URL,
        detailText: String,
        openSystemImage: String
    ) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Conversion Completed")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Output File")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.secondary)
                    Text(url.lastPathComponent)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }

            HStack(spacing: 12) {
                #if os(macOS)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Text("Show in Finder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open", systemImage: openSystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                #else
                ShareLink(item: url) {
                    Label("Share File", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                #endif
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.4), lineWidth: 1)
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

    private var audioDetailView: some View {
        VStack(spacing: 0) {
            Group {
                if !isAudioDropTargeted, let sourceURL = viewModel.audioSourceURL {
                    SelectedFileView(
                        url: sourceURL,
                        systemImage: "waveform",
                        isConverting: viewModel.isAudioConverting
                    ) {
                        withAnimation {
                            viewModel.clearSelectedAudioSource()
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    DropFileView(
                        isDropTargeted: isAudioDropTargeted,
                        placeholder: "Drop Audio Here"
                    ) {
                        viewModel.requestFileImport()
                    }
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.audioSourceURL)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAudioDropTargeted)
            .padding(20)

            Divider()

            Form {
                Section("Output Settings") {
                    Picker("Container", selection: $viewModel.selectedAudioOutputFormat) {
                        ForEach(viewModel.audioOutputFormatOptions) { format in
                            Text("\(format.displayName) (.\(format.fileExtension))").tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.audioOutputFormatOptions.isEmpty)

                    Picker("Audio Encoder", selection: $viewModel.selectedAudioOutputEncoder) {
                        ForEach(viewModel.audioOutputEncoderOptions) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(viewModel.audioOutputEncoderOptions.isEmpty)

                    Picker("Audio Mode", selection: $viewModel.selectedAudioOutputMode) {
                        ForEach(AudioModeOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    if viewModel.shouldShowAudioOutputSampleRateOption {
                        Picker("Sample Rate", selection: $viewModel.selectedAudioOutputSampleRate) {
                            ForEach(SampleRateOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if viewModel.shouldShowAudioOutputBitRateOption {
                        Picker("Audio Bit Rate", selection: $viewModel.selectedAudioOutputBitRate) {
                            ForEach(AudioBitRateOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if let hint = viewModel.audioFormatHintMessage {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Output File") {
                    if let convertedURL = viewModel.convertedAudioURL {
                        ConversionResultView(
                            url: convertedURL,
                            detailText: "Your audio is ready to play",
                            openSystemImage: "music.note"
                        )
                        .padding(.vertical, 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        Text("The converted file will appear here")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .safeAreaInset(edge: .bottom) {
            audioConversionControls
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.regularMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .top)
        }
        .navigationTitle("Convert Audio")
        .onDrop(of: [.fileURL], isTargeted: $isAudioDropTargeted) { providers in
            viewModel.handleAudioDrop(providers: providers)
        }
    }

    private var aboutDetailView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 128, height: 128)
                        .shadow(radius: 8)

                    VStack(spacing: 8) {
                        Text("MyConverter")
                            .font(.system(size: 32, weight: .bold))

                        Text(appVersionText)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Developer")
                        .font(.headline)
                    Text("Deferare")
                        .font(.body)

                    Divider()

                    Text("Contact")
                        .font(.headline)
                    if let contactURL = URL(string: "mailto:deferare@icloud.com") {
                        Link("deferare@icloud.com", destination: contactURL)
                            .font(.body)
                    } else {
                        Text("deferare@icloud.com")
                            .font(.body)
                    }

                    Divider()

                    Text("License")
                        .font(.headline)
                    Text("© 2026 Deferare. All rights reserved.")
                        .font(.body)
                    Button("Open Source Licenses") {
                        isShowingOpenSourceLicenses = true
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )

            }
            .padding(40)
            .frame(maxWidth: 600)
        }
        .navigationTitle("About")
        .sheet(isPresented: $isShowingOpenSourceLicenses) {
            openSourceLicensesSheet
        }
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildVersion) {
        case let (.some(short), .some(build)) where short != build:
            return "Version \(short) (\(build))"
        case let (.some(short), _):
            return "Version \(short)"
        case let (_, .some(build)):
            return "Version \(build)"
        default:
            return "Version"
        }
    }

    private var openSourceLicensesSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FFmpeg")
                            .font(.title3.weight(.semibold))

                        Text("This app bundles an LGPL-only FFmpeg 7.1 build.")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text("License: GNU Lesser General Public License v2.1 or later.")
                            .font(.body)

                        if let ffmpegURL = URL(string: "https://ffmpeg.org") {
                            Link("FFmpeg Project", destination: ffmpegURL)
                                .font(.callout)
                        }

                        if let lgplURL = URL(string: "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html") {
                            Link("GNU LGPL v2.1 Text", destination: lgplURL)
                                .font(.callout)
                        }
                    }

                    Divider()

                    Text("The bundled ffmpeg binary is validated during build to reject GPL-enabled configurations.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Open Source Licenses")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isShowingOpenSourceLicenses = false
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}

#Preview {
    ContentView()
}
