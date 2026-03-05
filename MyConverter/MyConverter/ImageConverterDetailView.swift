import SwiftUI

struct ImageConverterDetailView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    var body: some View {
        ConverterDetailContainer(
            title: "Convert Image",
            isDropTargeted: $isDropTargeted,
            onDrop: { providers in
                viewModel.handleImageDrop(providers: providers)
            },
            inputArea: {
                imageInputArea
            },
            formSections: {
                imageFormSections
            },
            controls: {
                imageConversionControls
            }
        )
    }

    @ViewBuilder
    private var imageInputArea: some View {
        ConverterInputArea(
            isDropTargeted: isDropTargeted,
            selectedURLs: viewModel.selectedImageSourceURLs,
            isConverting: viewModel.isImageConverting,
            systemImage: "photo.fill",
            dropPlaceholder: "Drop Image Here",
            fileDropAreaHeight: fileDropAreaHeight,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: {
                viewModel.requestFileImport()
            },
            onClear: {
                withAnimation {
                    viewModel.clearSelectedImageSource()
                }
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedImageSource(from: draggedURL, to: targetURL)
            }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.selectedImageFileCount)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTargeted)
    }

    @ViewBuilder
    private var imageFormSections: some View {
        ConverterFormSections(
            isConverting: viewModel.isImageConverting,
            outputURLs: viewModel.convertedImageURLs
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

    private var imageConversionControls: some View {
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
