import SwiftUI

struct VideoConverterDetailView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    var body: some View {
        ConverterDetailContainer(
            title: "Convert Video",
            isDropTargeted: $isDropTargeted,
            onDrop: { providers in
                viewModel.handleDrop(providers: providers, for: .video)
            },
            inputArea: {
                VideoConverterInputSectionView(
                    viewModel: viewModel,
                    isDropTargeted: isDropTargeted,
                    draggedSelectedFileURL: $draggedSelectedFileURL,
                    fileDropAreaHeight: fileDropAreaHeight
                )
            },
            formSections: {
                VideoConverterFormSectionView(viewModel: viewModel)
            },
            controls: {
                VideoConversionControlsView(viewModel: viewModel)
            }
        )
    }
}
