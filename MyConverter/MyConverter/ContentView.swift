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
        switch tab {
        case .video:
            VideoConverterDetailView(
                viewModel: viewModel,
                isDropTargeted: $isVideoDropTargeted,
                draggedSelectedFileURL: $draggedSelectedFileURL,
                fileDropAreaHeight: fileDropAreaHeight
            )
        case .image:
            ImageConverterDetailView(
                viewModel: viewModel,
                isDropTargeted: $isImageDropTargeted,
                draggedSelectedFileURL: $draggedSelectedFileURL,
                fileDropAreaHeight: fileDropAreaHeight
            )
        case .audio:
            AudioConverterDetailView(
                viewModel: viewModel,
                isDropTargeted: $isAudioDropTargeted,
                draggedSelectedFileURL: $draggedSelectedFileURL,
                fileDropAreaHeight: fileDropAreaHeight
            )
        case .about:
            AboutDetailView(donationStore: donationStore)
        }
    }
}

#Preview {
    ContentView()
}
