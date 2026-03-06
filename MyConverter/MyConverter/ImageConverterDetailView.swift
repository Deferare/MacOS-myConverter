import SwiftUI

struct ImageConverterDetailView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    var body: some View {
        MediaConverterDetailView(
            viewModel: viewModel,
            kind: .image,
            isDropTargeted: $isDropTargeted,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            fileDropAreaHeight: fileDropAreaHeight
        ) {
            ImageConverterFormSectionView(viewModel: viewModel)
        }
    }
}
