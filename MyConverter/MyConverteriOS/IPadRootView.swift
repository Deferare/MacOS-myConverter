#if os(iOS)
import SwiftUI

struct IPadRootView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var donationStore = DonationStore()
    @State private var selectedTab: ConverterTab = .video

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
            allowedContentTypes: viewModel.preferredImportTypes(for: selectedTab),
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileImportResult(result, for: selectedTab)
        }
    }
}
#endif
