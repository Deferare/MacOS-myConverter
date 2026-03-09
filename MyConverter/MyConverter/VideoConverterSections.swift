import SwiftUI

struct VideoConverterFormSectionView: View, Equatable {
    let state: ContentViewModel.VideoFormPresentationState
    let bindings: ContentViewModel.VideoFormBindings

    static func == (lhs: VideoConverterFormSectionView, rhs: VideoConverterFormSectionView) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        let _ = PerformanceSignpost.event("VideoFormRender")

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

            if state.shouldShowVideoEncoderOption {
                MenuPicker(
                    "Video Encoder",
                    selection: bindings.selectedVideoEncoder,
                    options: state.videoEncoderOptions,
                    disabledWhenEmpty: true,
                    label: { $0.rawValue }
                )
            }

            MenuPicker(
                "Resolution",
                selection: bindings.selectedResolution,
                options: Array(ResolutionOption.allCases),
                label: { $0.rawValue }
            )

            MenuPicker(
                "Frame Rate",
                selection: bindings.selectedFrameRate,
                options: Array(FrameRateOption.allCases),
                label: { $0.rawValue }
            )

            if state.shouldShowGIFPlaybackSpeedOption {
                MenuPicker(
                    "Playback Speed",
                    selection: bindings.selectedGIFPlaybackSpeed,
                    options: Array(GIFPlaybackSpeedOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if state.shouldShowVideoBitRateOption {
                MenuPicker(
                    "Video Bit Rate",
                    selection: bindings.selectedVideoBitRate,
                    options: Array(VideoBitRateOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if state.shouldShowVideoBitRateOption && state.selectedVideoBitRate == .custom {
                ConverterTextFieldRow(
                    "Custom Video Bit Rate",
                    prompt: "Custom Kbps (e.g. 5000)",
                    text: bindings.customVideoBitRate
                )
            }

            if state.shouldShowAudioSettings {
                MenuPicker(
                    "Audio Encoder",
                    selection: bindings.selectedAudioEncoder,
                    options: state.audioEncoderOptions,
                    disabledWhenEmpty: true,
                    label: { $0.rawValue }
                )

                AudioModeAndRatePickers(
                    modeSelection: bindings.selectedAudioMode,
                    sampleRateSelection: bindings.selectedSampleRate,
                    bitRateSelection: bindings.selectedAudioBitRate,
                    showSampleRate: state.shouldShowAudioSampleRateOption,
                    showBitRate: state.shouldShowAudioBitRateOption
                )
            }
        }
    }
}
