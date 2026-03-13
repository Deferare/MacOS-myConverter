import SwiftUI

extension ContentViewModel.MediaKind {
    @ViewBuilder
    func formSectionContent(viewModel: ContentViewModel) -> some View {
        switch self {
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

struct MediaSettingsFormContent: View {
    let kind: ContentViewModel.MediaKind
    let isConverting: Bool
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        OutputFolderSelectionRow(
            pathText: viewModel.selectedOutputDirectoryURL(for: kind).map {
                viewModel.abbreviatedOutputDirectoryPath($0)
            } ?? "No folder selected",
            hasSelection: viewModel.hasSelectedOutputDirectory(for: kind),
            tint: kind.liquidGlassTint,
            isDisabled: isConverting,
            onChoose: {
                Task {
                    await viewModel.chooseOutputDirectory(for: kind)
                }
            }
        )
        kind.formSectionContent(viewModel: viewModel)
    }
}
