import SwiftUI

struct VideoConverterFormSectionView: View, Equatable {
    let state: ContentViewModel.VideoFormPresentationState
    @ObservedObject private var viewModel: ContentViewModel

    init(viewModel: ContentViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        state = .init(viewModel: viewModel)
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
                selection: viewModel.binding(to: \.videoOptionsState.selectedOutputFormat),
                options: state.outputFormatOptions,
                disabledWhenEmpty: true,
                showsDivider: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            if state.shouldShowVideoEncoderOption {
                MenuPicker(
                    "Video Encoder",
                    selection: viewModel.binding(to: \.videoOptionsState.selectedVideoEncoder),
                    options: state.videoEncoderOptions,
                    disabledWhenEmpty: true,
                    showsDivider: true,
                    label: { $0.rawValue }
                )
            }

            MenuPicker(
                "Resolution",
                selection: viewModel.binding(to: \.videoOptionsState.selectedResolution),
                options: Array(ResolutionOption.allCases),
                showsDivider: true,
                label: { $0.rawValue }
            )

            MenuPicker(
                "Frame Rate",
                selection: viewModel.binding(to: \.videoOptionsState.selectedFrameRate),
                options: Array(FrameRateOption.allCases),
                showsDivider: showsPlaybackSpeed || showsVideoBitRate || showsCustomVideoBitRate || showsAudioSettings,
                label: { $0.rawValue }
            )

            if state.shouldShowGIFPlaybackSpeedOption {
                MenuPicker(
                    "Playback Speed",
                    selection: viewModel.binding(to: \.videoOptionsState.selectedGIFPlaybackSpeed),
                    options: Array(GIFPlaybackSpeedOption.allCases),
                    showsDivider: showsVideoBitRate || showsCustomVideoBitRate || showsAudioSettings,
                    label: { $0.rawValue }
                )
            }

            if state.shouldShowVideoBitRateOption {
                MenuPicker(
                    "Video Bit Rate",
                    selection: viewModel.binding(to: \.videoOptionsState.selectedVideoBitRate),
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
                    text: viewModel.binding(to: \.videoOptionsState.customVideoBitRate)
                )
            }

            if state.shouldShowAudioSettings {
                MenuPicker(
                    "Audio Encoder",
                    selection: viewModel.binding(to: \.videoOptionsState.selectedAudioEncoder),
                    options: state.audioSettings.encoderOptions,
                    disabledWhenEmpty: true,
                    showsDivider: true,
                    label: { $0.rawValue }
                )

                AudioModeAndRatePickers(
                    modeSelection: viewModel.binding(to: \.videoOptionsState.selectedAudioMode),
                    sampleRateSelection: viewModel.binding(to: \.videoOptionsState.selectedSampleRate),
                    bitRateSelection: viewModel.binding(to: \.videoOptionsState.selectedAudioBitRate),
                    showSampleRate: state.audioSettings.shouldShowSampleRateOption,
                    showBitRate: state.audioSettings.shouldShowBitRateOption,
                    showsDividerOnLastRow: false
                )
            }
        }
    }
}
