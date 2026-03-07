import SwiftUI

struct AudioModeAndRatePickers: View {
    @Binding var modeSelection: AudioModeOption
    @Binding var sampleRateSelection: SampleRateOption
    @Binding var bitRateSelection: AudioBitRateOption
    let showSampleRate: Bool
    let showBitRate: Bool

    var body: some View {
        MenuPicker(
            "Audio Mode",
            selection: $modeSelection,
            options: Array(AudioModeOption.allCases),
            label: { $0.rawValue }
        )

        if showSampleRate {
            MenuPicker(
                "Sample Rate",
                selection: $sampleRateSelection,
                options: Array(SampleRateOption.allCases),
                label: { $0.rawValue }
            )
        }

        if showBitRate {
            MenuPicker(
                "Audio Bit Rate",
                selection: $bitRateSelection,
                options: Array(AudioBitRateOption.allCases),
                label: { $0.rawValue }
            )
        }
    }
}
