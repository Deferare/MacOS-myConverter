#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IPadRootView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var donationStore = DonationStore()
    @State private var selectedTab: ConverterTab = .video

    private var photoLibraryImportBinding: Binding<ContentViewModel.ImportRequest?> {
        Binding(
            get: {
                viewModel.activePhotoLibraryImportRequest
            },
            set: { request in
                if let request {
                    viewModel.activeImportRequest = request
                    return
                }

                guard viewModel.activePhotoLibraryImportRequest != nil else { return }
                viewModel.finishActiveImportRequest()
            }
        )
    }

    private var activeFileImportTypes: [UTType] {
        guard let request = viewModel.activeFileImportRequest else { return [.item] }
        return viewModel.preferredImportTypes(for: request.kind)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TabSection("Media") {
                Tab(ConverterTab.video.title, systemImage: ConverterTab.video.systemImage, value: ConverterTab.video) {
                    NavigationStack {
                        IPadMediaConverterView(
                            kind: .video,
                            viewModel: viewModel
                        )
                    }
                }

                Tab(ConverterTab.audio.title, systemImage: ConverterTab.audio.systemImage, value: ConverterTab.audio) {
                    NavigationStack {
                        IPadMediaConverterView(
                            kind: .audio,
                            viewModel: viewModel
                        )
                    }
                }

                Tab(ConverterTab.image.title, systemImage: ConverterTab.image.systemImage, value: ConverterTab.image) {
                    NavigationStack {
                        IPadMediaConverterView(
                            kind: .image,
                            viewModel: viewModel
                        )
                    }
                }
            }

            TabSection("App") {
                Tab(ConverterTab.about.title, systemImage: ConverterTab.about.systemImage, value: ConverterTab.about) {
                    NavigationStack {
                        IPadAboutView(donationStore: donationStore)
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .task(id: selectedTab) {
            guard let kind = selectedTab.mediaKind else { return }
            viewModel.scheduleCapabilityBootstrap(for: kind)
        }
        .fileImporter(
            isPresented: $viewModel.isImporting,
            allowedContentTypes: activeFileImportTypes,
            allowsMultipleSelection: true
        ) { result in
            guard let request = viewModel.activeFileImportRequest else {
                viewModel.finishActiveImportRequest()
                return
            }

            viewModel.handleFileImportResult(result, for: request.kind)
            viewModel.finishActiveImportRequest()
        }
        .sheet(item: photoLibraryImportBinding) { request in
            IPadPhotoLibraryPicker(
                kind: request.kind,
                onComplete: { urls in
                    viewModel.applyImportedSources(urls, for: request.kind)
                    viewModel.finishActiveImportRequest()
                },
                onCancel: {
                    viewModel.finishActiveImportRequest()
                }
            )
        }
    }
}
#endif
