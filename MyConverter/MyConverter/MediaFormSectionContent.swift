import SwiftUI

extension ContentViewModel.MediaKind {
    @ViewBuilder
    func formSectionContent(viewModel: ContentViewModel) -> some View {
        switch self {
        case .video:
            VideoConverterFormSectionView(viewModel: viewModel)
            .equatable()
        case .image:
            ImageConverterFormSectionView(viewModel: viewModel)
            .equatable()
        case .audio:
            AudioConverterFormSectionView(viewModel: viewModel)
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
