import SwiftUI

struct AudioConverterInputSectionView: View {
    @ObservedObject var viewModel: ContentViewModel
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    private let fileSelectionAnimation: Animation = .easeOut(duration: 0.22)

    var body: some View {
        let selectedURLs = viewModel.selectedSourceURLs(for: .audio)

        ConverterInputArea(
            isDropTargeted: isDropTargeted,
            selectedURLs: selectedURLs,
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
                    viewModel.clearSelectedSource(for: .audio)
                }
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedSource(from: draggedURL, to: targetURL, for: .audio)
            }
        )
        .animation(fileSelectionAnimation, value: selectedURLs.count)
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

            if let hint = viewModel.hintMessage(for: .audio) {
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
        let validationMessage = viewModel.validationMessage(for: .audio)
        let hintMessage = viewModel.hintMessage(for: .audio)
        let status = viewModel.conversionStatus(
            for: .audio,
            validationMessage: validationMessage,
            hintMessage: hintMessage
        )
        let progress = viewModel.displayedProgress(for: .audio)

        ConversionControlBar(
            statusMessage: status.message,
            statusColor: status.level.color,
            progress: progress,
            progressText: viewModel.progressPercentageText(for: .audio),
            progressTint: progress > 0 ? .accentColor : .clear,
            isConverting: viewModel.isAudioConverting,
            canConvert: viewModel.canStartConversion(for: .audio, validationMessage: validationMessage),
            onStart: { viewModel.startConversion(for: .audio) },
            onCancel: { viewModel.cancelConversion(for: .audio) }
        )
    }
}
