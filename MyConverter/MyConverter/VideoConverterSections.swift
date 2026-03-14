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
        let settings = state.settings
        let showsPlaybackSpeed = settings.shouldShowGIFPlaybackSpeedOption
        let showsVideoBitRate = settings.shouldShowVideoBitRateOption
        let showsCustomVideoBitRate = showsVideoBitRate && settings.selectedVideoBitRate == .custom
        let showsAudioSettings = settings.shouldShowAudioSettings

        ConverterFormSections(
            isConverting: state.isConverting
        ) {
            MenuPicker(
                "Output Format",
                selection: viewModel.binding(to: \.videoOptionsState.selectedOutputFormat),
                options: settings.outputFormatOptions,
                disabledWhenEmpty: true,
                showsDivider: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            if settings.shouldShowVideoEncoderOption {
                MenuPicker(
                    "Video Encoder",
                    selection: viewModel.binding(to: \.videoOptionsState.selectedVideoEncoder),
                    options: settings.videoEncoderOptions,
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

            if settings.shouldShowGIFPlaybackSpeedOption {
                MenuPicker(
                    "Playback Speed",
                    selection: viewModel.binding(to: \.videoOptionsState.selectedGIFPlaybackSpeed),
                    options: Array(GIFPlaybackSpeedOption.allCases),
                    showsDivider: showsVideoBitRate || showsCustomVideoBitRate || showsAudioSettings,
                    label: { $0.rawValue }
                )
            }

            if settings.shouldShowVideoBitRateOption {
                MenuPicker(
                    "Video Bit Rate",
                    selection: viewModel.binding(to: \.videoOptionsState.selectedVideoBitRate),
                    options: Array(VideoBitRateOption.allCases),
                    showsDivider: showsCustomVideoBitRate || showsAudioSettings,
                    label: { $0.rawValue }
                )
            }

            if settings.shouldShowVideoBitRateOption && settings.selectedVideoBitRate == .custom {
                ConverterTextFieldRow(
                    "Custom Video Bit Rate",
                    prompt: "Custom Kbps (e.g. 5000)",
                    showsDivider: showsAudioSettings,
                    text: viewModel.binding(to: \.videoOptionsState.customVideoBitRate)
                )
            }

            if settings.shouldShowAudioSettings {
                MenuPicker(
                    "Audio Encoder",
                    selection: viewModel.binding(to: \.videoOptionsState.selectedAudioEncoder),
                    options: settings.audioSettings.encoderOptions,
                    disabledWhenEmpty: true,
                    showsDivider: true,
                    label: { $0.rawValue }
                )

                AudioModeAndRatePickers(
                    modeSelection: viewModel.binding(to: \.videoOptionsState.selectedAudioMode),
                    sampleRateSelection: viewModel.binding(to: \.videoOptionsState.selectedSampleRate),
                    bitRateSelection: viewModel.binding(to: \.videoOptionsState.selectedAudioBitRate),
                    showSampleRate: settings.audioSettings.shouldShowSampleRateOption,
                    showBitRate: settings.audioSettings.shouldShowBitRateOption,
                    showsDividerOnLastRow: false
                )
            }
        }
    }
}
