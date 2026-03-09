import SwiftUI

struct AudioConverterFormSectionView: View, Equatable {
    let state: ContentViewModel.AudioFormPresentationState
    let bindings: ContentViewModel.AudioFormBindings

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
                selection: bindings.selectedOutputFormat,
                options: state.outputFormatOptions,
                disabledWhenEmpty: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            MenuPicker(
                "Audio Encoder",
                selection: bindings.selectedOutputEncoder,
                options: state.audioOutputEncoderOptions,
                disabledWhenEmpty: true,
                label: { $0.rawValue }
            )

            AudioModeAndRatePickers(
                modeSelection: bindings.selectedOutputMode,
                sampleRateSelection: bindings.selectedOutputSampleRate,
                bitRateSelection: bindings.selectedOutputBitRate,
                showSampleRate: state.shouldShowAudioOutputSampleRateOption,
                showBitRate: state.shouldShowAudioOutputBitRateOption
            )

            if let hint = state.hintMessage {
                ConverterSettingsHint(text: hint)
            }
        }
    }
}
