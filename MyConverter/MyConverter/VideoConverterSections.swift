import SwiftUI

struct VideoConverterFormSectionView: View, Equatable {
    let state: ContentViewModel.VideoFormPresentationState
    let bindings: ContentViewModel.VideoFormBindings

    init(viewModel: ContentViewModel) {
        self.init(
            state: .init(viewModel: viewModel),
            bindings: .init(viewModel: viewModel)
        )
    }

    static func == (lhs: VideoConverterFormSectionView, rhs: VideoConverterFormSectionView) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        let _ = PerformanceSignpost.event("VideoFormRender")
        let showsPlaybackSpeed = state.shouldShowGIFPlaybackSpeedOption
        let showsVideoBitRate = state.shouldShowVideoBitRateOption
        let showsCustomVideoBitRate = showsVideoBitRate && state.selectedVideoBitRate == .custom
        let showsAudioSettings = state.shouldShowAudioSettings

        ConverterFormSections(
            isConverting: state.isConverting
        ) {
            MenuPicker(
                "Output Format",
                selection: bindings.selectedOutputFormat,
                options: state.outputFormatOptions,
                disabledWhenEmpty: true,
                showsDivider: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            if state.shouldShowVideoEncoderOption {
                MenuPicker(
                    "Video Encoder",
                    selection: bindings.selectedVideoEncoder,
                    options: state.videoEncoderOptions,
                    disabledWhenEmpty: true,
                    showsDivider: true,
                    label: { $0.rawValue }
                )
            }

            MenuPicker(
                "Resolution",
                selection: bindings.selectedResolution,
                options: Array(ResolutionOption.allCases),
                showsDivider: true,
                label: { $0.rawValue }
            )

            MenuPicker(
                "Frame Rate",
                selection: bindings.selectedFrameRate,
                options: Array(FrameRateOption.allCases),
                showsDivider: showsPlaybackSpeed || showsVideoBitRate || showsCustomVideoBitRate || showsAudioSettings,
                label: { $0.rawValue }
            )

            if state.shouldShowGIFPlaybackSpeedOption {
                MenuPicker(
                    "Playback Speed",
                    selection: bindings.selectedGIFPlaybackSpeed,
                    options: Array(GIFPlaybackSpeedOption.allCases),
                    showsDivider: showsVideoBitRate || showsCustomVideoBitRate || showsAudioSettings,
                    label: { $0.rawValue }
                )
            }

            if state.shouldShowVideoBitRateOption {
                MenuPicker(
                    "Video Bit Rate",
                    selection: bindings.selectedVideoBitRate,
                    options: Array(VideoBitRateOption.allCases),
                    showsDivider: showsCustomVideoBitRate || showsAudioSettings,
                    label: { $0.rawValue }
                )
            }

            if state.shouldShowVideoBitRateOption && state.selectedVideoBitRate == .custom {
                ConverterTextFieldRow(
                    "Custom Video Bit Rate",
                    prompt: "Custom Kbps (e.g. 5000)",
                    showsDivider: showsAudioSettings,
                    text: bindings.customVideoBitRate
                )
            }

            if state.shouldShowAudioSettings {
                MenuPicker(
                    "Audio Encoder",
                    selection: bindings.selectedAudioEncoder,
                    options: state.audioEncoderOptions,
                    disabledWhenEmpty: true,
                    showsDivider: true,
                    label: { $0.rawValue }
                )

                AudioModeAndRatePickers(
                    modeSelection: bindings.selectedAudioMode,
                    sampleRateSelection: bindings.selectedSampleRate,
                    bitRateSelection: bindings.selectedAudioBitRate,
                    showSampleRate: state.shouldShowAudioSampleRateOption,
                    showBitRate: state.shouldShowAudioBitRateOption,
                    showsDividerOnLastRow: false
                )
            }
        }
    }
}
