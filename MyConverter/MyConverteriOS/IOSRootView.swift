#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IOSRootView: View {
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
        IOSLayoutReader { layout in
            Group {
                switch layout {
                case .compact:
                    IOSCompactRootContent(
                        viewModel: viewModel,
                        donationStore: donationStore,
                        selectedTab: $selectedTab
                    )
                case .regular:
                    IOSRegularRootContent(
                        viewModel: viewModel,
                        donationStore: donationStore,
                        selectedTab: $selectedTab
                    )
                }
            }
            .task(id: selectedTab) {
                guard let kind = selectedTab.mediaKind else { return }
                viewModel.scheduleCapabilityBootstrap(for: kind)
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

struct IOSCompactRootContent: View {
    @ObservedObject var viewModel: ContentViewModel
    @ObservedObject var donationStore: DonationStore
    @Binding var selectedTab: ConverterTab

    var body: some View {
        TabView(selection: $selectedTab) {
            IOSMediaRootTabItem(kind: .video, viewModel: viewModel)
            IOSMediaRootTabItem(kind: .audio, viewModel: viewModel)
            IOSMediaRootTabItem(kind: .image, viewModel: viewModel)
            IOSAboutRootTabItem(donationStore: donationStore)
        }
    }
}

struct IOSMediaRootTabItem: View {
    let kind: ContentViewModel.MediaKind
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        let tab = ConverterTab(rawValue: kind.rawValue) ?? .video
        Tab(tab.title, systemImage: tab.systemImage, value: tab) {
            NavigationStack {
                IPadMediaConverterView(
                    kind: kind,
                    viewModel: viewModel
                )
            }
        }
    }
}

struct IOSAboutRootTabItem: View {
    @ObservedObject var donationStore: DonationStore

    var body: some View {
        Tab(
            ConverterTab.about.title,
            systemImage: ConverterTab.about.systemImage,
            value: ConverterTab.about
        ) {
            NavigationStack {
                IPadAboutView(donationStore: donationStore)
            }
        }
    }
}
#endif
