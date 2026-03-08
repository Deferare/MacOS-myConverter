import SwiftUI

struct ImageConverterFormSectionView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ConverterFormSections(
            isConverting: viewModel.isImageConverting
        ) {
            MenuPicker(
                "Output Format",
                selection: $viewModel.selectedImageOutputFormat,
                options: viewModel.imageOutputFormatOptions,
                disabledWhenEmpty: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            MenuPicker(
                "Resolution",
                selection: $viewModel.selectedImageResolution,
                options: Array(ResolutionOption.allCases),
                label: { $0.rawValue }
            )

            if viewModel.shouldShowImageQualityOption {
                MenuPicker(
                    "Quality",
                    selection: $viewModel.selectedImageQuality,
                    options: Array(ImageQualityOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if viewModel.shouldShowPNGCompressionOption {
                MenuPicker(
                    "PNG Compression",
                    selection: $viewModel.selectedPNGCompressionLevel,
                    options: Array(PNGCompressionLevelOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if viewModel.shouldShowPreserveAnimationOption {
                ConverterToggleRow("Preserve Animation", isOn: $viewModel.preserveImageAnimation)
            }

            if let hint = viewModel.hintMessage(for: .image) {
                ConverterSettingsHint(text: hint)
            }
        }
    }
}
