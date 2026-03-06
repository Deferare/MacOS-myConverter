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
                viewModel.handleDrop(providers: providers, for: .image)
            },
            inputArea: {
                ImageConverterInputSectionView(
                    viewModel: viewModel,
                    isDropTargeted: isDropTargeted,
                    draggedSelectedFileURL: $draggedSelectedFileURL,
                    fileDropAreaHeight: fileDropAreaHeight
                )
            },
            formSections: {
                ImageConverterFormSectionView(viewModel: viewModel)
            },
            controls: {
                ImageConversionControlsView(viewModel: viewModel)
            }
        )
    }
}
