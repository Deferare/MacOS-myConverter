import SwiftUI

struct AboutInfoSection: View {
    let onOpenLicenses: () -> Void

    var body: some View {
        Group {
            aboutSection(title: "Developer", value: "JiHoon K (Deferare)")
            Divider()
            aboutSection(title: "Contact", value: "deferare@icloud.com", isLink: true)
            Divider()
            aboutSection(title: "License", value: "© 2026 Deferare. All rights reserved.")

            Button("Open Source Licenses") {
                onOpenLicenses()
            }
            .buttonStyle(.link)
            .font(.subheadline.weight(.medium))

            Divider()
        }
    }

    @ViewBuilder
    private func aboutSection(title: String, value: String, isLink: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if isLink, let url = title == "Contact" ? URL(string: "mailto:\(value)") : URL(string: value) {
                Link(value, destination: url)
                    .font(.body.weight(.medium))
            } else {
                Text(value)
                    .font(.body.weight(.medium))
            }
        }
    }
}
