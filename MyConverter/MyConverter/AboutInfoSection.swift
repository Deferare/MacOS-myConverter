import SwiftUI

struct AboutInfoSection: View {
    let onOpenLicenses: () -> Void

    var body: some View {
        AboutPanelCard {
            VStack(alignment: .leading, spacing: 18) {
                AboutSectionHeader(
                    title: "About",
                    subtitle: "Developer details, contact, and licensing information.",
                    systemImage: "person.text.rectangle"
                )

                VStack(spacing: 10) {
                    AboutMetadataRow(
                        title: "Developer",
                        value: "JiHoon K (Deferare)",
                        systemImage: "person.crop.circle"
                    )

                    Link(destination: URL(string: "mailto:deferare@icloud.com")!) {
                        AboutMetadataRow(
                            title: "Contact",
                            value: "deferare@icloud.com",
                            systemImage: "envelope",
                            trailingSystemImage: "arrow.up.right",
                            emphasizesValue: true
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    AboutMetadataRow(
                        title: "License",
                        value: "© 2026 Deferare. All rights reserved.",
                        systemImage: "c.circle"
                    )

                    Button {
                        onOpenLicenses()
                    } label: {
                        AboutMetadataRow(
                            title: "Open Source Licenses",
                            value: "View bundled acknowledgements and license text.",
                            systemImage: "doc.text.magnifyingglass",
                            trailingSystemImage: "chevron.right"
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
