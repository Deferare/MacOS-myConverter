#if os(iOS)
import SwiftUI

struct IPadRootView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var donationStore = DonationStore()
    @State private var selectedTab: ConverterTab = .video

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(ConverterTab.allCases) { tab in
                Group {
                    if let kind = tab.mediaKind {
                        IPadMediaConverterView(
                            kind: kind,
                            viewModel: viewModel
                        )
                    } else {
                        IPadAboutView(donationStore: donationStore)
                    }
                }
                .tag(tab)
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
            }
        }
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
