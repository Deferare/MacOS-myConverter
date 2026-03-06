import SwiftUI

struct VideoConverterDetailView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    var body: some View {
        MediaConverterDetailView(
            viewModel: viewModel,
            kind: .video,
            isDropTargeted: $isDropTargeted,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            fileDropAreaHeight: fileDropAreaHeight
        ) {
            VideoConverterFormSectionView(viewModel: viewModel)
        }
    }
}
