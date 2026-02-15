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
        VStack(spacing: 0) {
            videoInputArea
                .padding(24)
            
            Form {
                videoFormSections
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

    @ViewBuilder
    private var videoInputArea: some View {
        Group {
            if !isVideoDropTargeted, !viewModel.selectedVideoSourceURLs.isEmpty {
                SelectedFilesView(
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
                DropFileView(
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
                        OutputFileCardView(
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
        VStack(spacing: 0) {
            imageInputArea
                .padding(24)
            
            Form {
                imageFormSections
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

    @ViewBuilder
    private var imageInputArea: some View {
        Group {
            if !isImageDropTargeted, !viewModel.selectedImageSourceURLs.isEmpty {
                SelectedFilesView(
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
                DropFileView(
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
                        OutputFileCardView(
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
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(viewModel.conversionStatusMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(videoConversionStatusColor)
                        .lineLimit(1)

                    Spacer()

                    Text(viewModel.progressPercentageText)
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: viewModel.displayedConversionProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(videoProgressTintColor)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    .clipShape(Capsule())
            }

            Button {
                if viewModel.isConverting {
                    viewModel.cancelConversion()
                } else {
                    viewModel.startConversion()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isConverting ? "xmark.circle.fill" : "play.fill")
                    Text(viewModel.isConverting ? "Cancel" : "Start Conversion")
                }
                .font(.body.bold())
                .frame(minWidth: 140, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isConverting ? false : !viewModel.canConvert)
            .shadow(color: .accentColor.opacity(viewModel.canConvert ? 0.2 : 0), radius: 8, x: 0, y: 4)
        }
    }

    private var imageConversionControls: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(viewModel.imageConversionStatusMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(imageConversionStatusColor)
                        .lineLimit(1)

                    Spacer()

                    Text(viewModel.imageProgressPercentageText)
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: viewModel.displayedImageConversionProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(imageProgressTintColor)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    .clipShape(Capsule())
            }

            Button {
                if viewModel.isImageConverting {
                    viewModel.cancelImageConversion()
                } else {
                    viewModel.startImageConversion()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isImageConverting ? "xmark.circle.fill" : "play.fill")
                    Text(viewModel.isImageConverting ? "Cancel" : "Start Conversion")
                }
                .font(.body.bold())
                .frame(minWidth: 140, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isImageConverting ? false : !viewModel.canConvertImage)
            .shadow(color: .accentColor.opacity(viewModel.canConvertImage ? 0.2 : 0), radius: 8, x: 0, y: 4)
        }
    }

    private var audioConversionControls: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(viewModel.audioConversionStatusMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(audioConversionStatusColor)
                        .lineLimit(1)

                    Spacer()

                    Text(viewModel.audioProgressPercentageText)
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: viewModel.displayedAudioConversionProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(audioProgressTintColor)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    .clipShape(Capsule())
            }

            Button {
                if viewModel.isAudioConverting {
                    viewModel.cancelAudioConversion()
                } else {
                    viewModel.startAudioConversion()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isAudioConverting ? "xmark.circle.fill" : "play.fill")
                    Text(viewModel.isAudioConverting ? "Cancel" : "Start Conversion")
                }
                .font(.body.bold())
                .frame(minWidth: 140, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isAudioConverting ? false : !viewModel.canConvertAudio)
            .shadow(color: .accentColor.opacity(viewModel.canConvertAudio ? 0.2 : 0), radius: 8, x: 0, y: 4)
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
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.accentColor.opacity(0.04))
                        .frame(width: 100, height: 100)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isDropTargeted)

                    Image(systemName: isDropTargeted ? "square.and.arrow.down.fill" : "arrow.down.doc.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isDropTargeted)
                }

                VStack(spacing: 10) {
                    Text(isDropTargeted ? "Drop to Import" : placeholder)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .primary)

                    Text(isDropTargeted ? "Release to start conversion setup" : "or click to browse local files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: fileDropAreaHeight)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.04) : Color.primary.opacity(0.02))

                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: isDropTargeted ? [] : [6, 4])
                        )
                }
            )
            .contentShape(Rectangle())
            .scaleEffect(isDropTargeted ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTargeted)
        }
        .buttonStyle(.plain)
    }

    private func SelectedFilesView(
        urls: [URL],
        systemImage: String,
        isConverting: Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Selected Files")
                    .font(.headline)

                Text("\(urls.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.14))
                    )

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: urls.count > 4) {
                HStack(spacing: 12) {
                    ForEach(Array(urls.enumerated()), id: \.element.path) { index, url in
                        SelectedFileCardView(
                            url: url,
                            order: index + 1,
                            systemImage: systemImage
                        )
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack(spacing: 12) {
                Text("Ready for conversion")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

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
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: fileDropAreaHeight, maxHeight: fileDropAreaHeight)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private func SelectedFileCardView(
        url: URL,
        order: Int,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }

                Spacer(minLength: 0)

                Text("\(order)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(url.lastPathComponent)
                .font(.footnote.weight(.semibold))
                .lineLimit(3)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(url.pathExtension.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.12))
                )
        }
        .padding(12)
        .frame(width: 130, height: 130)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func OutputFileCardView(
        url: URL,
        order: Int,
        openSystemImage: String
    ) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("#\(order)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    Text(url.lastPathComponent)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text(url.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 14, weight: .medium))
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
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
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
        VStack(spacing: 0) {
            audioInputArea
                .padding(24)
            
            Form {
                audioFormSections
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

    @ViewBuilder
    private var audioInputArea: some View {
        Group {
            if !isAudioDropTargeted, !viewModel.selectedAudioSourceURLs.isEmpty {
                SelectedFilesView(
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
                DropFileView(
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
                        OutputFileCardView(
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
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

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
                        AboutSection(title: "Developer", value: "JiHoon K (Deferare)")
                        Divider()
                        AboutSection(title: "Contact", value: "deferare@icloud.com", isLink: true)
                        Divider()
                        AboutSection(title: "License", value: "© 2026 Deferare. All rights reserved.")
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

    private func AboutSection(title: String, value: String, isLink: Bool = false) -> some View {
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
        List(selection: $selectedTab) {
            Section("Converter") {
                sidebarTabItems
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MyConverter")
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
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
        if let image = NSImage(named: "AppIcon")
            ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) {
            return Image(nsImage: image)
        }
        return Image(systemName: "app.dashed")
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
