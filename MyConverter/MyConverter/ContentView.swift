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
    @State private var isVideoDropTargeted = false
    @State private var isImageDropTargeted = false
    @State private var isAudioDropTargeted = false
    @State private var draggedSelectedFileURL: URL?

    private var fileDropAreaHeight: CGFloat {
        300
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
        switch kind {
        case .video:
            return $isVideoDropTargeted
        case .image:
            return $isImageDropTargeted
        case .audio:
            return $isAudioDropTargeted
        }
    }

    @ViewBuilder
    private func mediaFormSections(for kind: ContentViewModel.MediaKind) -> some View {
        switch kind {
        case .video:
            VideoConverterFormSectionView(viewModel: viewModel)
        case .image:
            ImageConverterFormSectionView(viewModel: viewModel)
        case .audio:
            AudioConverterFormSectionView(viewModel: viewModel)
        }
    }

    private func mediaDetailView(for kind: ContentViewModel.MediaKind) -> some View {
        MediaConverterDetailView(
            viewModel: viewModel,
            kind: kind,
            isDropTargeted: dropTargetBinding(for: kind),
            draggedSelectedFileURL: $draggedSelectedFileURL,
            fileDropAreaHeight: fileDropAreaHeight
        ) {
            mediaFormSections(for: kind)
        }
    }
}

#Preview {
    ContentView()
}
