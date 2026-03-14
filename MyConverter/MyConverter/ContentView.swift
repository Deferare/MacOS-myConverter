//
//  ContentView.swift
//  MyConverter
//
//  Created by JiHoon K on 2/14/26.
//

import SwiftUI
import UniformTypeIdentifiers

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
                if let kind = selectedTab.mediaKind {
                    viewModel.scheduleCapabilityBootstrap(for: kind)
                }
            }
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: selectedTab.mediaKind.map {
                    $0.preferredImportTypes()
                } ?? [.item],
            allowsMultipleSelection: true
        ) { result in
                selectedTab.mediaKind?.handleFileImportResult(result, in: viewModel)
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
        let renderState = kind.converterRenderState(in: viewModel)

        return MediaConverterDetailView(
            kind: kind,
            renderState: renderState,
            isDropTargeted: dropTargetBinding(for: kind),
            draggedSelectedFileURL: $draggedSelectedFileURL,
            fileDropAreaHeight: fileDropAreaHeight,
            onDrop: { providers in
                kind.handleDrop(providers: providers, in: viewModel)
            },
            onImport: {
                kind.requestFileImport(in: viewModel)
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedSource(from: draggedURL, to: targetURL, for: kind)
            },
            onClear: {
                kind.clearSelectedSource(in: viewModel)
            },
            onPrimaryAction: {
                if renderState.screenState.isConverting {
                    kind.cancelConversion(in: viewModel)
                } else {
                    kind.startConversion(in: viewModel)
                }
            }
        ) {
            mediaFormSections(for: kind, screenState: renderState.screenState)
        }
    }

    @ViewBuilder
    private func mediaFormSections(
        for kind: ContentViewModel.MediaKind,
        screenState: ContentViewModel.ConverterScreenState
    ) -> some View {
        MediaSettingsFormContent(
            kind: kind,
            isConverting: screenState.isConverting,
            viewModel: viewModel
        )
    }

}

#Preview {
    ContentView()
}
