import SwiftUI

struct VideoConverterFormSectionView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ConverterFormSections(
            isConverting: viewModel.isConverting
        ) {
            MenuPicker(
                "Output Format",
                selection: $viewModel.selectedOutputFormat,
                options: viewModel.outputFormatOptions,
                disabledWhenEmpty: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            if viewModel.shouldShowVideoEncoderOption {
                MenuPicker(
                    "Video Encoder",
                    selection: $viewModel.selectedVideoEncoder,
                    options: viewModel.videoEncoderOptions,
                    disabledWhenEmpty: true,
                    label: { $0.rawValue }
                )
            }

            MenuPicker(
                "Resolution",
                selection: $viewModel.selectedResolution,
                options: Array(ResolutionOption.allCases),
                label: { $0.rawValue }
            )

            MenuPicker(
                "Frame Rate",
                selection: $viewModel.selectedFrameRate,
                options: Array(FrameRateOption.allCases),
                label: { $0.rawValue }
            )

            if viewModel.shouldShowGIFPlaybackSpeedOption {
                MenuPicker(
                    "Playback Speed",
                    selection: $viewModel.selectedGIFPlaybackSpeed,
                    options: Array(GIFPlaybackSpeedOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if viewModel.shouldShowVideoBitRateOption {
                MenuPicker(
                    "Video Bit Rate",
                    selection: $viewModel.selectedVideoBitRate,
                    options: Array(VideoBitRateOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if viewModel.shouldShowVideoBitRateOption && viewModel.selectedVideoBitRate == .custom {
                TextField("Custom Kbps (e.g. 5000)", text: $viewModel.customVideoBitRate)
                    .textFieldStyle(.roundedBorder)
            }

            if viewModel.shouldShowAudioSettings {
                MenuPicker(
                    "Audio Encoder",
                    selection: $viewModel.selectedAudioEncoder,
                    options: viewModel.audioEncoderOptions,
                    disabledWhenEmpty: true,
                    label: { $0.rawValue }
                )

                AudioModeAndRatePickers(
                    modeSelection: $viewModel.selectedAudioMode,
                    sampleRateSelection: $viewModel.selectedSampleRate,
                    bitRateSelection: $viewModel.selectedAudioBitRate,
                    showSampleRate: viewModel.shouldShowAudioSampleRateOption,
                    showBitRate: viewModel.shouldShowAudioBitRateOption
                )
            }
        }
    }
}
