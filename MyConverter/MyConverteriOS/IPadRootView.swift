#if os(iOS)
import SwiftUI

struct IOSRegularRootContent: View {
    @ObservedObject var viewModel: ContentViewModel
    @ObservedObject var donationStore: DonationStore
    @Binding var selectedTab: ConverterTab

    var body: some View {
        TabView(selection: $selectedTab) {
            TabSection("Media") {
                IOSMediaRootTabItem(kind: .video, viewModel: viewModel)
                IOSMediaRootTabItem(kind: .audio, viewModel: viewModel)
                IOSMediaRootTabItem(kind: .image, viewModel: viewModel)
            }

            TabSection("App") {
                IOSAboutRootTabItem(donationStore: donationStore)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
#endif
