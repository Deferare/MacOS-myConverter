import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: ConverterTab

    private let mediaTabs: [ConverterTab] = [.video, .audio, .image]
    private let appTabs: [ConverterTab] = [.about]

    private var sidebarSelectionTint: Color {
        selectedTab.mediaKind?.liquidGlassTint ?? .accentColor
    }

    var body: some View {
        List(selection: $selectedTab) {
            Section("Media") {
                sidebarTabItems(for: mediaTabs)
            }

            Section("App") {
                sidebarTabItems(for: appTabs)
            }
        }
        .listStyle(.sidebar)
        .tint(sidebarSelectionTint)
        .navigationTitle("MyConverter")
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }

    @ViewBuilder
    private func sidebarTabItems(for tabs: [ConverterTab]) -> some View {
        ForEach(tabs) { tab in
            Label(tab.title, systemImage: tab.systemImage)
                .font(.body.weight(.medium))
                .padding(.vertical, 2)
                .tag(tab)
        }
    }
}
