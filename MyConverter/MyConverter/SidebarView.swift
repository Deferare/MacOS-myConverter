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
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: -2) {
                Text("MyConverter")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Personal Media Tool")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.8))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
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
