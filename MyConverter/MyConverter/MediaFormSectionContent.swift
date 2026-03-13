import SwiftUI

struct MediaFormSectionContent: View {
    let kind: ContentViewModel.MediaKind
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        switch kind {
        case .video:
            VideoConverterFormSectionView(
                state: viewModel.videoFormPresentationState(),
                bindings: viewModel.videoFormBindings()
            )
            .equatable()
        case .image:
            ImageConverterFormSectionView(
                state: viewModel.imageFormPresentationState(),
                bindings: viewModel.imageFormBindings()
            )
            .equatable()
        case .audio:
            AudioConverterFormSectionView(
                state: viewModel.audioFormPresentationState(),
                bindings: viewModel.audioFormBindings()
            )
            .equatable()
        }
    }
}
