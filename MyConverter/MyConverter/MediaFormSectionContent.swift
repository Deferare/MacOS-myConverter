import SwiftUI

extension ContentViewModel.MediaKind {
    private static let formSectionContentByKind: [Self: @MainActor (ContentViewModel) -> AnyView] = [
        .video: { AnyView(VideoConverterFormSectionView(viewModel: $0).equatable()) },
        .image: { AnyView(ImageConverterFormSectionView(viewModel: $0).equatable()) },
        .audio: { AnyView(AudioConverterFormSectionView(viewModel: $0).equatable()) }
    ]

    @MainActor
    func formSectionContent(viewModel: ContentViewModel) -> AnyView {
        Self.formSectionContentByKind[self]?(viewModel)
            ?? AnyView(VideoConverterFormSectionView(viewModel: viewModel).equatable())
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
