import SwiftUI

struct AudioConverterDetailView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    var body: some View {
        ConverterDetailContainer(
            title: "Convert Audio",
            isDropTargeted: $isDropTargeted,
            onDrop: { providers in
                viewModel.handleAudioDrop(providers: providers)
            },
            inputArea: {
                AudioConverterInputSectionView(
                    viewModel: viewModel,
                    isDropTargeted: isDropTargeted,
                    draggedSelectedFileURL: $draggedSelectedFileURL,
                    fileDropAreaHeight: fileDropAreaHeight
                )
            },
            formSections: {
                AudioConverterFormSectionView(viewModel: viewModel)
            },
            controls: {
                AudioConversionControlsView(viewModel: viewModel)
            }
        )
    }
}
