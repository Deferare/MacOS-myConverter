import AppKit
import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: ConverterTab

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List(selection: $selectedTab) {
                Section("Converter") {
                    sidebarTabItems
                }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("MyConverter")
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 14) {
            appIconImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .padding(8)
                .glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("MyConverter")
                    .font(.headline)
                Text("Personal Media Tool")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
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

    private var appIconImage: Image {
        if let image = NSImage(named: "AppIcon") {
            return Image(nsImage: image)
        }
        return Image(systemName: "circle.hexagonpath.fill")
    }
}
