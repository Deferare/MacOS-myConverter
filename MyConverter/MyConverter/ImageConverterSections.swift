import SwiftUI

struct ImageConverterFormSectionView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ConverterFormSections(
            isConverting: viewModel.isImageConverting
        ) {
            MenuPicker(
                "Container",
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
                Toggle("Preserve Animation", isOn: $viewModel.preserveImageAnimation)
            }

            if let hint = viewModel.hintMessage(for: .image) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
