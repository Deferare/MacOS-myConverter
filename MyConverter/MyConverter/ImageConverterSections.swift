import SwiftUI

struct ImageConverterInputSectionView: View {
    @ObservedObject var viewModel: ContentViewModel
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    private let fileSelectionAnimation: Animation = .easeOut(duration: 0.22)

    var body: some View {
        ConverterInputArea(
            isDropTargeted: isDropTargeted,
            selectedURLs: viewModel.selectedImageSourceURLs,
            outputURLs: viewModel.convertedImageURLs,
            isConverting: viewModel.isImageConverting,
            currentBatchIndex: viewModel.currentImageBatchIndex,
            systemImage: "photo.fill",
            dropPlaceholder: "Drop Image Here",
            fileDropAreaHeight: fileDropAreaHeight,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: {
                viewModel.requestFileImport()
            },
            onClear: {
                withAnimation(fileSelectionAnimation) {
                    viewModel.clearSelectedImageSource()
                }
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedImageSource(from: draggedURL, to: targetURL)
            }
        )
        .animation(fileSelectionAnimation, value: viewModel.selectedImageFileCount)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTargeted)
    }
}

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

            if let hint = viewModel.imageFormatHintMessage {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ImageConversionControlsView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ConversionControlBar(
            statusMessage: viewModel.imageConversionStatusMessage,
            statusColor: viewModel.imageConversionStatusLevel.color,
            progress: viewModel.displayedImageConversionProgress,
            progressText: viewModel.imageProgressPercentageText,
            progressTint: viewModel.displayedImageConversionProgress > 0 ? .accentColor : .clear,
            isConverting: viewModel.isImageConverting,
            canConvert: viewModel.canConvertImage,
            onStart: { viewModel.startImageConversion() },
            onCancel: { viewModel.cancelImageConversion() }
        )
    }
}
