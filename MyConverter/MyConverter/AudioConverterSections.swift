import SwiftUI

struct AudioConverterInputSectionView: View {
    @ObservedObject var viewModel: ContentViewModel
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    private let fileSelectionAnimation: Animation = .easeOut(duration: 0.22)

    var body: some View {
        ConverterInputArea(
            isDropTargeted: isDropTargeted,
            selectedURLs: viewModel.selectedAudioSourceURLs,
            outputURLs: viewModel.convertedAudioURLs,
            isConverting: viewModel.isAudioConverting,
            currentBatchIndex: viewModel.currentAudioBatchIndex,
            systemImage: "waveform",
            dropPlaceholder: "Drop Files Here",
            fileDropAreaHeight: fileDropAreaHeight,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: {
                viewModel.requestFileImport()
            },
            onClear: {
                withAnimation(fileSelectionAnimation) {
                    viewModel.clearSelectedAudioSource()
                }
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedAudioSource(from: draggedURL, to: targetURL)
            }
        )
        .animation(fileSelectionAnimation, value: viewModel.selectedAudioFileCount)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTargeted)
    }
}

struct AudioConverterFormSectionView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ConverterFormSections(
            isConverting: viewModel.isAudioConverting
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
}

struct AudioConversionControlsView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ConversionControlBar(
            statusMessage: viewModel.audioConversionStatusMessage,
            statusColor: viewModel.audioConversionStatusLevel.color,
            progress: viewModel.displayedAudioConversionProgress,
            progressText: viewModel.audioProgressPercentageText,
            progressTint: viewModel.displayedAudioConversionProgress > 0 ? .accentColor : .clear,
            isConverting: viewModel.isAudioConverting,
            canConvert: viewModel.canConvertAudio,
            onStart: { viewModel.startAudioConversion() },
            onCancel: { viewModel.cancelAudioConversion() }
        )
    }
}
