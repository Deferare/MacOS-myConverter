import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: ConverterTab

    var body: some View {
        List(selection: $selectedTab) {
            Section("Converter") {
                sidebarTabItems
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MyConverter")
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }

    @ViewBuilder
    private var sidebarTabItems: some View {
        ForEach(ConverterTab.allCases) { tab in
            Label(tab.title, systemImage: tab.systemImage)
                .font(.body.weight(.medium))
                .padding(.vertical, 2)
                .tag(tab)
        }
    }
}
