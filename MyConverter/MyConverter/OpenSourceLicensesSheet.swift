import SwiftUI

struct OpenSourceLicensesSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    licenseSection(
                        title: "FFmpeg",
                        description: "This app bundles an LGPL-only FFmpeg 7.1 build.",
                        links: [
                            ("FFmpeg Project", "https://ffmpeg.org"),
                            ("GNU LGPL v2.1 Text", "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html")
                        ]
                    )

                    Divider()

                    licenseSection(
                        title: "FFmpeg-iOS",
                        description: "The iPad app uses the FFmpeg-iOS and FFmpeg-iOS-Support packages to invoke FFmpeg in-process.",
                        links: [
                            ("FFmpeg-iOS Package", "https://github.com/kewlbear/FFmpeg-iOS"),
                            ("FFmpeg-iOS-Support Package", "https://github.com/kewlbear/FFmpeg-iOS-Support")
                        ]
                    )

                    Divider()

                    Text("The bundled ffmpeg binary is validated during build to reject GPL-enabled configurations.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Open Source Licenses")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#if os(macOS)
        .frame(minWidth: 560, minHeight: 420)
#else
        .frame(minHeight: 420)
#endif
    }

    @ViewBuilder
    private func licenseSection(
        title: String,
        description: String,
        links: [(label: String, urlString: String)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("License: GNU Lesser General Public License v2.1 or later.")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                if let url = URL(string: link.urlString) {
                    Link(link.label, destination: url)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
