#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IOSRootView: View {
    @StateObject private var viewModel = ContentViewModel()
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
        return request.kind.preferredImportTypes()
    }

    var body: some View {
        IOSLayoutReader { layout in
            Group {
                switch layout {
                case .compact:
                    IOSCompactRootContent(
                        viewModel: viewModel,
                        selectedTab: $selectedTab
                    )
                case .regular:
                    IOSRegularRootContent(
                        viewModel: viewModel,
                        selectedTab: $selectedTab
                    )
                }
            }
            .task(id: selectedTab) {
                if let kind = selectedTab.mediaKind {
                    kind.scheduleCapabilityBootstrap(in: viewModel)
                }
            }
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

            request.kind.handleFileImportResult(result, in: viewModel)
            viewModel.finishActiveImportRequest()
        }
        .sheet(item: photoLibraryImportBinding) { request in
            IPadPhotoLibraryPicker(
                kind: request.kind,
                onComplete: { urls in
                    request.kind.applyImportedSources(urls, in: viewModel)
                    viewModel.finishActiveImportRequest()
                },
                onCancel: {
                    viewModel.finishActiveImportRequest()
                }
            )
        }
    }
}

struct IOSCompactRootContent: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selectedTab: ConverterTab

    var body: some View {
        TabView(selection: $selectedTab) {
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

            Tab(ConverterTab.about.title, systemImage: ConverterTab.about.systemImage, value: ConverterTab.about) {
                NavigationStack {
                    IPadAboutView()
                }
            }
        }
    }
}
#endif
