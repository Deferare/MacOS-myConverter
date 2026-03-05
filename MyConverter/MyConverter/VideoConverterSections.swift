import SwiftUI

struct VideoConverterInputSectionView: View {
    @ObservedObject var viewModel: ContentViewModel
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    var body: some View {
        ConverterInputArea(
            isDropTargeted: isDropTargeted,
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTargeted)
    }
}

struct VideoConverterFormSectionView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
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
}

struct VideoConversionControlsView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ConversionControlBar(
            statusMessage: viewModel.conversionStatusMessage,
            statusColor: viewModel.conversionStatusLevel.color,
            progress: viewModel.displayedConversionProgress,
            progressText: viewModel.progressPercentageText,
            progressTint: viewModel.displayedConversionProgress > 0 ? .accentColor : .clear,
            isConverting: viewModel.isConverting,
            canConvert: viewModel.canConvert,
            onStart: { viewModel.startConversion() },
            onCancel: { viewModel.cancelConversion() }
        )
    }
}
