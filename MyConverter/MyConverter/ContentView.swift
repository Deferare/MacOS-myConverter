//
//  ContentView.swift
//  MyConverter
//
//  Created by JiHoon K on 2/14/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var donationStore = DonationStore()
    @State private var selectedTab: ConverterTab = .video
    @State private var dropTargetedKinds: Set<ContentViewModel.MediaKind> = []
    @State private var draggedSelectedFileURL: URL?

    private var fileDropAreaHeight: CGFloat {
        468
    }

    var body: some View {
        rootNavigationView
            .task(id: selectedTab) {
                guard let kind = selectedTab.mediaKind else { return }
                viewModel.scheduleCapabilityBootstrap(for: kind)
            }
            .fileImporter(
                isPresented: $viewModel.isImporting,
                allowedContentTypes: viewModel.preferredImportTypes(for: selectedTab),
                allowsMultipleSelection: true
            ) { result in
                viewModel.handleFileImportResult(result, for: selectedTab)
            }
    }

    @ViewBuilder
    private var rootNavigationView: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
        } detail: {
            detailView(for: selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 880, minHeight: 620)
    }


    @ViewBuilder
    private func detailView(for tab: ConverterTab) -> some View {
        if let kind = tab.mediaKind {
            mediaDetailView(for: kind)
        } else {
            AboutDetailView(donationStore: donationStore)
        }
    }

    private func dropTargetBinding(for kind: ContentViewModel.MediaKind) -> Binding<Bool> {
        Binding(
            get: {
                dropTargetedKinds.contains(kind)
            },
            set: { isTargeted in
                if isTargeted {
                    dropTargetedKinds.insert(kind)
                } else {
                    dropTargetedKinds.remove(kind)
                }
            }
        )
    }

    private func mediaDetailView(for kind: ContentViewModel.MediaKind) -> some View {
        let renderState = viewModel.converterRenderState(for: kind)
        let screenState = renderState.screenState

        return MediaConverterDetailView(
            kind: kind,
            screenState: screenState,
            inputHeaderState: renderState.inputHeaderState,
            selectedFileListState: renderState.selectedFileListState,
            isDropTargeted: dropTargetBinding(for: kind),
            draggedSelectedFileURL: $draggedSelectedFileURL,
            fileDropAreaHeight: fileDropAreaHeight,
            onDrop: { providers in
                viewModel.handleDrop(providers: providers, for: kind)
            },
            onImport: {
                viewModel.requestFileImport()
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedSource(from: draggedURL, to: targetURL, for: kind)
            },
            onClear: {
                viewModel.clearSelectedSource(for: kind)
            },
            onPrimaryAction: {
                if screenState.isConverting {
                    viewModel.cancelConversion(for: kind)
                } else {
                    viewModel.startConversion(for: kind)
                }
            }
        ) {
            mediaFormSections(for: kind, screenState: screenState)
        }
    }

    @ViewBuilder
    private func mediaFormSections(
        for kind: ContentViewModel.MediaKind,
        screenState: ContentViewModel.ConverterScreenState
    ) -> some View {
        OutputFolderSelectionRow(
            pathText: viewModel.selectedOutputDirectoryURL(for: kind).map {
                viewModel.abbreviatedOutputDirectoryPath($0)
            } ?? "No folder selected",
            hasSelection: viewModel.hasSelectedOutputDirectory(for: kind),
            tint: kind.liquidGlassTint,
            isDisabled: screenState.isConverting,
            onChoose: {
                viewModel.chooseOutputDirectory(for: kind)
            }
        )

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

#Preview {
    ContentView()
}
