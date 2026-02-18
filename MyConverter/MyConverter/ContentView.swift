//
//  ContentView.swift
//  MyConverter
//
//  Created by JiHoon K on 2/14/26.
//

import SwiftUI
import StoreKit
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var donationStore = DonationStore()
    @State private var selectedTab: ConverterTab = .video
    @State private var isVideoDropTargeted = false
    @State private var isImageDropTargeted = false
    @State private var isAudioDropTargeted = false
    @State private var isShowingOpenSourceLicenses = false

    private var fileDropAreaHeight: CGFloat {
        240
    }

    var body: some View {
        rootNavigationView
            .fileImporter(
                isPresented: $viewModel.isImporting,
                allowedContentTypes: viewModel.preferredImportTypes(for: selectedTab),
                allowsMultipleSelection: true
            ) { result in
                viewModel.handleFileImportResult(result, for: selectedTab)
            }
    }

    @ViewBuilder
    private var rootNavigationView: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView(for: selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 980, minHeight: 620)
    }


    @ViewBuilder
    private func detailView(for tab: ConverterTab) -> some View {
        switch tab {
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

    private var videoDetailView: some View {
        ZStack {
            detailBackground
            
            VStack(spacing: 0) {
                videoInputArea
                    .padding(24)
                
                Form {
                    videoFormSections
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomControlContainer {
                videoConversionControls
            }
        }
        .navigationTitle("Convert Video")
        .onDrop(of: [.fileURL], isTargeted: $isVideoDropTargeted) { providers in
            viewModel.handleVideoDrop(providers: providers)
        }
    }

    @ViewBuilder
    private var videoInputArea: some View {
        Group {
            if !isVideoDropTargeted, !viewModel.selectedVideoSourceURLs.isEmpty {
                selectedFilesView(
                    urls: viewModel.selectedVideoSourceURLs,
                    systemImage: "film.fill",
                    isConverting: viewModel.isConverting
                ) {
                    withAnimation {
                        viewModel.clearSelectedVideoSource()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                dropFileView(
                    isDropTargeted: isVideoDropTargeted,
                    placeholder: "Drop Video Here"
                ) {
                    viewModel.requestFileImport()
                }
                .transition(.scale(scale: 0.98).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.selectedVideoFileCount)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVideoDropTargeted)
    }

    @ViewBuilder
    private var videoFormSections: some View {
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
        .disabled(viewModel.isConverting)

        Section("Output Files") {
            if viewModel.convertedURLs.isEmpty {
                Text("Converted files will appear here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.convertedURLs.enumerated()), id: \.element.path) { index, url in
                        outputFileCardView(
                            url: url,
                            order: index + 1,
                            openSystemImage: "play.fill"
                        )
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private var imageDetailView: some View {
        ZStack {
            detailBackground
            
            VStack(spacing: 0) {
                imageInputArea
                    .padding(24)
                
                Form {
                    imageFormSections
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomControlContainer {
                imageConversionControls
            }
        }
        .navigationTitle("Convert Image")
        .onDrop(of: [.fileURL], isTargeted: $isImageDropTargeted) { providers in
            viewModel.handleImageDrop(providers: providers)
        }
    }

    @ViewBuilder
    private var imageInputArea: some View {
        Group {
            if !isImageDropTargeted, !viewModel.selectedImageSourceURLs.isEmpty {
                selectedFilesView(
                    urls: viewModel.selectedImageSourceURLs,
                    systemImage: "photo.fill",
                    isConverting: viewModel.isImageConverting
                ) {
                    withAnimation {
                        viewModel.clearSelectedImageSource()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                dropFileView(
                    isDropTargeted: isImageDropTargeted,
                    placeholder: "Drop Image Here"
                ) {
                    viewModel.requestFileImport()
                }
                .transition(.scale(scale: 0.98).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.selectedImageFileCount)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isImageDropTargeted)
    }

    @ViewBuilder
    private var imageFormSections: some View {
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
        .disabled(viewModel.isImageConverting)

        Section("Output Files") {
            if viewModel.convertedImageURLs.isEmpty {
                Text("Converted files will appear here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.convertedImageURLs.enumerated()), id: \.element.path) { index, url in
                        outputFileCardView(
                            url: url,
                            order: index + 1,
                            openSystemImage: "photo.fill"
                        )
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private var videoConversionControls: some View {
        conversionControlBar(
            statusMessage: viewModel.conversionStatusMessage,
            statusColor: videoConversionStatusColor,
            progress: viewModel.displayedConversionProgress,
            progressText: viewModel.progressPercentageText,
            progressTint: videoProgressTintColor,
            isConverting: viewModel.isConverting,
            canConvert: viewModel.canConvert,
            onStart: { viewModel.startConversion() },
            onCancel: { viewModel.cancelConversion() }
        )
    }

    private var imageConversionControls: some View {
        conversionControlBar(
            statusMessage: viewModel.imageConversionStatusMessage,
            statusColor: imageConversionStatusColor,
            progress: viewModel.displayedImageConversionProgress,
            progressText: viewModel.imageProgressPercentageText,
            progressTint: imageProgressTintColor,
            isConverting: viewModel.isImageConverting,
            canConvert: viewModel.canConvertImage,
            onStart: { viewModel.startImageConversion() },
            onCancel: { viewModel.cancelImageConversion() }
        )
    }

    private var audioConversionControls: some View {
        conversionControlBar(
            statusMessage: viewModel.audioConversionStatusMessage,
            statusColor: audioConversionStatusColor,
            progress: viewModel.displayedAudioConversionProgress,
            progressText: viewModel.audioProgressPercentageText,
            progressTint: audioProgressTintColor,
            isConverting: viewModel.isAudioConverting,
            canConvert: viewModel.canConvertAudio,
            onStart: { viewModel.startAudioConversion() },
            onCancel: { viewModel.cancelAudioConversion() }
        )
    }

    private func conversionControlBar(
        statusMessage: String,
        statusColor: Color,
        progress: Double,
        progressText: String,
        progressTint: Color,
        isConverting: Bool,
        canConvert: Bool,
        onStart: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text(statusMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)

                    Spacer()

                    Text(progressText)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(progressTint)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .clipShape(Capsule())
                    .animation(.spring(), value: progress)
            }

            Button {
                if isConverting {
                    onCancel()
                } else {
                    onStart()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isConverting ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .black))
                    Text(isConverting ? "Cancel" : "Start Conversion")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(minWidth: 150, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isConverting ? false : !canConvert)
            .shadow(color: (isConverting || canConvert) ? Color.accentColor.opacity(0.2) : .clear, radius: 10, x: 0, y: 4)
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

    private func dropFileView(
        isDropTargeted: Bool,
        placeholder: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.15) : Color.accentColor.opacity(0.05))
                        .frame(width: 88, height: 88)
                        .blur(radius: isDropTargeted ? 10 : 0)
                        .scaleEffect(isDropTargeted ? 1.15 : 1.0)
                    
                    Circle()
                        .stroke(Color.accentColor.opacity(isDropTargeted ? 0.3 : 0.1), lineWidth: 1)
                        .frame(width: 104, height: 104)
                        .scaleEffect(isDropTargeted ? 1.05 : 1.0)

                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                }

                VStack(spacing: 8) {
                    Text(isDropTargeted ? "Drop to Import" : placeholder)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .primary)

                    Text(isDropTargeted ? "Release to start conversion setup" : "or click to browse local files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: fileDropAreaHeight)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.03) : Color.primary.opacity(0.01))

                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: isDropTargeted ? [] : [4, 4])
                        )
                }
            )
            .contentShape(Rectangle())
            .scaleEffect(isDropTargeted ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDropTargeted)
    }

    private func selectedFilesView(
        urls: [URL],
        systemImage: String,
        isConverting: Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text("Selected Files")
                    .font(.headline)

                Text("\(urls.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.secondary.opacity(0.1))
                    )

                Spacer()
                
                if !isConverting {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(urls.enumerated()), id: \.element.path) { index, url in
                        selectedFileCardView(
                            url: url,
                            order: index + 1,
                            systemImage: systemImage
                        )
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack {
                Text("Ready for conversion")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    viewModel.requestFileImport()
                } label: {
                    Label("Add Files", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isConverting)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: fileDropAreaHeight, maxHeight: fileDropAreaHeight)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.background.opacity(0.4).shadow(.inner(color: .white.opacity(0.1), radius: 0, x: 0, y: 1)))
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func selectedFileCardView(
        url: URL,
        order: Int,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 28, height: 28)
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                Text("\(order)")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.6))
            }

            Spacer(minLength: 4)

            Text(url.lastPathComponent)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(url.pathExtension.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.primary.opacity(0.05))
                    )
                Spacer()
            }
        }
        .padding(12)
        .frame(width: 140, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background.opacity(0.4))
                .background(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }

    private func outputFileCardView(
        url: URL,
        order: Int,
        openSystemImage: String
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(order)")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.05)))

                    Text(url.lastPathComponent)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text(url.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .help("Show in Finder")

                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open", systemImage: openSystemImage)
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background.opacity(0.4))
                .background(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
    }

    private func conversionResultView(
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
        Color(nsColor: .controlBackgroundColor)
    }

    private var audioDetailView: some View {
        ZStack {
            detailBackground
            
            VStack(spacing: 0) {
                audioInputArea
                    .padding(24)
                
                Form {
                    audioFormSections
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomControlContainer {
                audioConversionControls
            }
        }
        .navigationTitle("Convert Audio")
        .onDrop(of: [.fileURL], isTargeted: $isAudioDropTargeted) { providers in
            viewModel.handleAudioDrop(providers: providers)
        }
    }

    private var detailBackground: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }

    private func bottomControlContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.primary.opacity(0.05)), alignment: .top)
    }

    @ViewBuilder
    private var audioInputArea: some View {
        Group {
            if !isAudioDropTargeted, !viewModel.selectedAudioSourceURLs.isEmpty {
                selectedFilesView(
                    urls: viewModel.selectedAudioSourceURLs,
                    systemImage: "waveform",
                    isConverting: viewModel.isAudioConverting
                ) {
                    withAnimation {
                        viewModel.clearSelectedAudioSource()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                dropFileView(
                    isDropTargeted: isAudioDropTargeted,
                    placeholder: "Drop Audio Here"
                ) {
                    viewModel.requestFileImport()
                }
                .transition(.scale(scale: 0.98).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.selectedAudioFileCount)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAudioDropTargeted)
    }

    @ViewBuilder
    private var audioFormSections: some View {
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
        .disabled(viewModel.isAudioConverting)

        Section("Output Files") {
            if viewModel.convertedAudioURLs.isEmpty {
                Text("Converted files will appear here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.convertedAudioURLs.enumerated()), id: \.element.path) { index, url in
                        outputFileCardView(
                            url: url,
                            order: index + 1,
                            openSystemImage: "music.note"
                        )
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    private var aboutDetailView: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    appIconImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)

                    VStack(spacing: 8) {
                        Text("MyConverter")
                            .font(.system(size: 36, weight: .black))

                        Text(appVersionText)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 60)

                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        aboutSection(title: "Developer", value: "JiHoon K (Deferare)")
                        Divider()
                        aboutSection(title: "Contact", value: "deferare@icloud.com", isLink: true)
                        Divider()
                        aboutSection(title: "License", value: "© 2026 Deferare. All rights reserved.")
                    }

                    Button("Open Source Licenses") {
                        isShowingOpenSourceLicenses = true
                    }
                    .buttonStyle(.link)
                    .font(.subheadline.weight(.medium))

                    Divider()

                    Text("Support Development")
                        .font(.headline)

                    Text("MyConverter is a labor of love. If you find it useful, consider supporting its continued development.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if donationStore.isLoadingProducts {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading support options...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if donationStore.products.isEmpty {
                        Button("Reload Support Options") {
                            Task {
                                await donationStore.loadProducts()
                            }
                        }
                        .buttonStyle(.bordered)
                    } else {
                        HStack(spacing: 12) {
                            ForEach(donationStore.products.sorted(by: { $0.price < $1.price }), id: \.id) { product in
                                Button {
                                    Task {
                                        await donationStore.purchase(product)
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(donationStore.suggestedAmountText(for: product.id))
                                            .font(.subheadline.weight(.bold))
                                        Text(product.displayPrice)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        if donationStore.purchasingProductID == product.id {
                                            ProgressView()
                                                .controlSize(.small)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                }
                                .buttonStyle(.bordered)
                                .disabled(
                                    donationStore.isLoadingProducts ||
                                    (donationStore.purchasingProductID != nil && donationStore.purchasingProductID != product.id)
                                )
                            }
                        }

                        Text("Thank you for your support!")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if let statusMessage = donationStore.statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(donationStore.statusIsError ? .red : .secondary)
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.primary.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                )

                Text("Built with SwiftUI & FFmpeg")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("About")
        .task {
            await donationStore.loadProductsIfNeeded()
        }
        .sheet(isPresented: $isShowingOpenSourceLicenses) {
            openSourceLicensesSheet
        }
    }

    private func aboutSection(title: String, value: String, isLink: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            if isLink, let url = title == "Contact" ? URL(string: "mailto:\(value)") : URL(string: value) {
                Link(value, destination: url)
                    .font(.body.weight(.medium))
            } else {
                Text(value)
                    .font(.body.weight(.medium))
            }
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

    private var sidebarView: some View {
        VStack(spacing: 0) {
            sidebarHeader
            
            List(selection: $selectedTab) {
                Section("Converter") {
                    sidebarTabItems
                }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("MyConverter")
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            appIconImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 0) {
                Text("MyConverter")
                    .font(.headline.weight(.heavy))
                Text("Ultimate Tool")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var sidebarTabItems: some View {
        ForEach(ConverterTab.allCases) { tab in
            Label(tab.title, systemImage: tab.systemImage)
                .font(.body.weight(.medium))
                .padding(.vertical, 2)
                .tag(tab)
        }
    }

    private var appIconImage: Image {
        if let image = NSImage(named: "AppIcon") {
            return Image(nsImage: image)
        }
        return Image(systemName: "circle.hexagonpath.fill")
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
