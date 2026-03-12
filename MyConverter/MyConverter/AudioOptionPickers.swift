import SwiftUI

struct AudioModeAndRatePickers: View {
    @Binding var modeSelection: AudioModeOption
    @Binding var sampleRateSelection: SampleRateOption
    @Binding var bitRateSelection: AudioBitRateOption
    let showSampleRate: Bool
    let showBitRate: Bool
    var showsDividerOnLastRow = true

    var body: some View {
        MenuPicker(
            "Audio Mode",
            selection: $modeSelection,
            options: Array(AudioModeOption.allCases),
            showsDivider: showSampleRate || showBitRate || showsDividerOnLastRow,
            label: { $0.rawValue }
        )

        if showSampleRate {
            MenuPicker(
                "Sample Rate",
                selection: $sampleRateSelection,
                options: Array(SampleRateOption.allCases),
                showsDivider: showBitRate || showsDividerOnLastRow,
                label: { $0.rawValue }
            )
        }

        if showBitRate {
            MenuPicker(
                "Audio Bit Rate",
                selection: $bitRateSelection,
                options: Array(AudioBitRateOption.allCases),
                showsDivider: showsDividerOnLastRow,
                label: { $0.rawValue }
            )
        }
    }
}
