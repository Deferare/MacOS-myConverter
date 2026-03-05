//
//  ContentView.swift
//  MyConverter
//
//  Created by JiHoon K on 2/14/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var donationStore = DonationStore()
    @State private var selectedTab: ConverterTab = .video
    @State private var isVideoDropTargeted = false
    @State private var isImageDropTargeted = false
    @State private var isAudioDropTargeted = false
    @State private var draggedSelectedFileURL: URL?

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
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            detailView(for: selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 880, minHeight: 620)
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
        ConverterDetailContainer(
            title: "Convert Video",
            isDropTargeted: $isVideoDropTargeted,
            onDrop: { providers in
                viewModel.handleVideoDrop(providers: providers)
            },
            inputArea: {
                videoInputArea
            },
            formSections: {
                videoFormSections
            },
            controls: {
                videoConversionControls
            }
        )
    }

    @ViewBuilder
    private var videoInputArea: some View {
        ConverterInputArea(
            isDropTargeted: isVideoDropTargeted,
            selectedURLs: viewModel.selectedVideoSourceURLs,
            isConverting: viewModel.isConverting,
            systemImage: "film.fill",
            dropPlaceholder: "Drop Video Here",
            fileDropAreaHeight: fileDropAreaHeight,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: {
                viewModel.requestFileImport()
            },
            onClear: {
                withAnimation {
                    viewModel.clearSelectedVideoSource()
                }
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedVideoSource(from: draggedURL, to: targetURL)
            }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.selectedVideoFileCount)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVideoDropTargeted)
    }

    @ViewBuilder
    private var videoFormSections: some View {
        ConverterFormSections(
            isConverting: viewModel.isConverting,
            outputURLs: viewModel.convertedURLs
        ) {
            MenuPicker(
                "Container",
                selection: $viewModel.selectedOutputFormat,
                options: viewModel.outputFormatOptions,
                disabledWhenEmpty: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            if viewModel.shouldShowVideoEncoderOption {
                MenuPicker(
                    "Video Encoder",
                    selection: $viewModel.selectedVideoEncoder,
                    options: viewModel.videoEncoderOptions,
                    disabledWhenEmpty: true,
                    label: { $0.rawValue }
                )
            }

            MenuPicker(
                "Resolution",
                selection: $viewModel.selectedResolution,
                options: Array(ResolutionOption.allCases),
                label: { $0.rawValue }
            )

            MenuPicker(
                "Frame Rate",
                selection: $viewModel.selectedFrameRate,
                options: Array(FrameRateOption.allCases),
                label: { $0.rawValue }
            )

            if viewModel.shouldShowGIFPlaybackSpeedOption {
                MenuPicker(
                    "Playback Speed",
                    selection: $viewModel.selectedGIFPlaybackSpeed,
                    options: Array(GIFPlaybackSpeedOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if viewModel.shouldShowVideoBitRateOption {
                MenuPicker(
                    "Video Bit Rate",
                    selection: $viewModel.selectedVideoBitRate,
                    options: Array(VideoBitRateOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if viewModel.shouldShowVideoBitRateOption && viewModel.selectedVideoBitRate == .custom {
                TextField("Custom Kbps (e.g. 5000)", text: $viewModel.customVideoBitRate)
                    .textFieldStyle(.roundedBorder)
            }

            if viewModel.shouldShowAudioSettings {
                MenuPicker(
                    "Audio Encoder",
                    selection: $viewModel.selectedAudioEncoder,
                    options: viewModel.audioEncoderOptions,
                    disabledWhenEmpty: true,
                    label: { $0.rawValue }
                )

                AudioModeAndRatePickers(
                    modeSelection: $viewModel.selectedAudioMode,
                    sampleRateSelection: $viewModel.selectedSampleRate,
                    bitRateSelection: $viewModel.selectedAudioBitRate,
                    showSampleRate: viewModel.shouldShowAudioSampleRateOption,
                    showBitRate: viewModel.shouldShowAudioBitRateOption
                )
            }
        }
    }

    private var imageDetailView: some View {
        ConverterDetailContainer(
            title: "Convert Image",
            isDropTargeted: $isImageDropTargeted,
            onDrop: { providers in
                viewModel.handleImageDrop(providers: providers)
            },
            inputArea: {
                imageInputArea
            },
            formSections: {
                imageFormSections
            },
            controls: {
                imageConversionControls
            }
        )
    }

    @ViewBuilder
    private var imageInputArea: some View {
        ConverterInputArea(
            isDropTargeted: isImageDropTargeted,
            selectedURLs: viewModel.selectedImageSourceURLs,
            isConverting: viewModel.isImageConverting,
            systemImage: "photo.fill",
            dropPlaceholder: "Drop Image Here",
            fileDropAreaHeight: fileDropAreaHeight,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: {
                viewModel.requestFileImport()
            },
            onClear: {
                withAnimation {
                    viewModel.clearSelectedImageSource()
                }
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedImageSource(from: draggedURL, to: targetURL)
            }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.selectedImageFileCount)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isImageDropTargeted)
    }

    @ViewBuilder
    private var imageFormSections: some View {
        ConverterFormSections(
            isConverting: viewModel.isImageConverting,
            outputURLs: viewModel.convertedImageURLs
        ) {
            MenuPicker(
                "Container",
                selection: $viewModel.selectedImageOutputFormat,
                options: viewModel.imageOutputFormatOptions,
                disabledWhenEmpty: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            MenuPicker(
                "Resolution",
                selection: $viewModel.selectedImageResolution,
                options: Array(ResolutionOption.allCases),
                label: { $0.rawValue }
            )

            if viewModel.shouldShowImageQualityOption {
                MenuPicker(
                    "Quality",
                    selection: $viewModel.selectedImageQuality,
                    options: Array(ImageQualityOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if viewModel.shouldShowPNGCompressionOption {
                MenuPicker(
                    "PNG Compression",
                    selection: $viewModel.selectedPNGCompressionLevel,
                    options: Array(PNGCompressionLevelOption.allCases),
                    label: { $0.rawValue }
                )
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
    }

    private var videoConversionControls: some View {
        ConversionControlBar(
            statusMessage: viewModel.conversionStatusMessage,
            statusColor: statusColor(for: viewModel.conversionStatusLevel),
            progress: viewModel.displayedConversionProgress,
            progressText: viewModel.progressPercentageText,
            progressTint: progressTintColor(for: viewModel.displayedConversionProgress),
            isConverting: viewModel.isConverting,
            canConvert: viewModel.canConvert,
            onStart: { viewModel.startConversion() },
            onCancel: { viewModel.cancelConversion() }
        )
    }

    private var imageConversionControls: some View {
        ConversionControlBar(
            statusMessage: viewModel.imageConversionStatusMessage,
            statusColor: statusColor(for: viewModel.imageConversionStatusLevel),
            progress: viewModel.displayedImageConversionProgress,
            progressText: viewModel.imageProgressPercentageText,
            progressTint: progressTintColor(for: viewModel.displayedImageConversionProgress),
            isConverting: viewModel.isImageConverting,
            canConvert: viewModel.canConvertImage,
            onStart: { viewModel.startImageConversion() },
            onCancel: { viewModel.cancelImageConversion() }
        )
    }

    private var audioConversionControls: some View {
        ConversionControlBar(
            statusMessage: viewModel.audioConversionStatusMessage,
            statusColor: statusColor(for: viewModel.audioConversionStatusLevel),
            progress: viewModel.displayedAudioConversionProgress,
            progressText: viewModel.audioProgressPercentageText,
            progressTint: progressTintColor(for: viewModel.displayedAudioConversionProgress),
            isConverting: viewModel.isAudioConverting,
            canConvert: viewModel.canConvertAudio,
            onStart: { viewModel.startAudioConversion() },
            onCancel: { viewModel.cancelAudioConversion() }
        )
    }

    private func progressTintColor(for progress: Double) -> Color {
        progress > 0 ? .accentColor : .clear
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


    @ViewBuilder
    private var audioInputArea: some View {
        ConverterInputArea(
            isDropTargeted: isAudioDropTargeted,
            selectedURLs: viewModel.selectedAudioSourceURLs,
            isConverting: viewModel.isAudioConverting,
            systemImage: "waveform",
            dropPlaceholder: "Drop Audio Here",
            fileDropAreaHeight: fileDropAreaHeight,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: {
                viewModel.requestFileImport()
            },
            onClear: {
                withAnimation {
                    viewModel.clearSelectedAudioSource()
                }
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedAudioSource(from: draggedURL, to: targetURL)
            }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.selectedAudioFileCount)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAudioDropTargeted)
    }

    private var audioDetailView: some View {
        ConverterDetailContainer(
            title: "Convert Audio",
            isDropTargeted: $isAudioDropTargeted,
            onDrop: { providers in
                viewModel.handleAudioDrop(providers: providers)
            },
            inputArea: {
                audioInputArea
            },
            formSections: {
                audioFormSections
            },
            controls: {
                audioConversionControls
            }
        )
    }

    @ViewBuilder
    private var audioFormSections: some View {
        ConverterFormSections(
            isConverting: viewModel.isAudioConverting,
            outputURLs: viewModel.convertedAudioURLs
        ) {
            MenuPicker(
                "Container",
                selection: $viewModel.selectedAudioOutputFormat,
                options: viewModel.audioOutputFormatOptions,
                disabledWhenEmpty: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            MenuPicker(
                "Audio Encoder",
                selection: $viewModel.selectedAudioOutputEncoder,
                options: viewModel.audioOutputEncoderOptions,
                disabledWhenEmpty: true,
                label: { $0.rawValue }
            )

            AudioModeAndRatePickers(
                modeSelection: $viewModel.selectedAudioOutputMode,
                sampleRateSelection: $viewModel.selectedAudioOutputSampleRate,
                bitRateSelection: $viewModel.selectedAudioOutputBitRate,
                showSampleRate: viewModel.shouldShowAudioOutputSampleRateOption,
                showBitRate: viewModel.shouldShowAudioOutputBitRateOption
            )

            if let hint = viewModel.audioFormatHintMessage {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutDetailView: some View {
        AboutDetailView(donationStore: donationStore)
    }
}

#Preview {
    ContentView()
}
