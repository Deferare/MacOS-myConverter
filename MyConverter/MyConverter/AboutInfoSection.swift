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

                VStack(spacing: 0) {
                    AboutMetadataRow(
                        title: "Developer",
                        value: "JiHoon K (Deferare)",
                        systemImage: "person.crop.circle"
                    )

                    AboutSectionDivider()

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

                    AboutSectionDivider()

                    AboutMetadataRow(
                        title: "License",
                        value: "© 2026 Deferare. All rights reserved.",
                        systemImage: "c.circle"
                    )

                    AboutSectionDivider()

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
