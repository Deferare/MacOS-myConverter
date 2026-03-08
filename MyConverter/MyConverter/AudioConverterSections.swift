import SwiftUI

struct AudioConverterFormSectionView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ConverterFormSections(
            isConverting: viewModel.isAudioConverting
        ) {
            MenuPicker(
                "Output Format",
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
