import SwiftUI

struct AudioConverterFormSectionView: View, Equatable {
    let state: ContentViewModel.AudioFormPresentationState
    @ObservedObject private var viewModel: ContentViewModel

    init(viewModel: ContentViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        state = .init(viewModel: viewModel)
    }

    static func == (lhs: AudioConverterFormSectionView, rhs: AudioConverterFormSectionView) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        let _ = PerformanceSignpost.event("AudioFormRender")

        ConverterFormSections(
            isConverting: state.isConverting
        ) {
            MenuPicker(
                "Output Format",
                selection: viewModel.binding(to: \.audioOptionsState.selectedOutputFormat),
                options: state.outputFormatOptions,
                disabledWhenEmpty: true,
                showsDivider: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            MenuPicker(
                "Audio Encoder",
                selection: viewModel.binding(to: \.audioOptionsState.selectedOutputEncoder),
                options: state.audioSettings.encoderOptions,
                disabledWhenEmpty: true,
                showsDivider: true,
                label: { $0.rawValue }
            )

            AudioModeAndRatePickers(
                modeSelection: viewModel.binding(to: \.audioOptionsState.selectedOutputMode),
                sampleRateSelection: viewModel.binding(to: \.audioOptionsState.selectedOutputSampleRate),
                bitRateSelection: viewModel.binding(to: \.audioOptionsState.selectedOutputBitRate),
                showSampleRate: state.audioSettings.shouldShowSampleRateOption,
                showBitRate: state.audioSettings.shouldShowBitRateOption,
                showsDividerOnLastRow: state.hintMessage != nil
            )

            if let hint = state.hintMessage {
                ConverterSettingsHint(text: hint, showsDivider: false)
            }
        }
    }
}
