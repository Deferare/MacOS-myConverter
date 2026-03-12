import SwiftUI

struct OpenSourceLicensesSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FFmpeg")
                            .font(.title3.weight(.semibold))

                        Text("This app bundles an LGPL-only FFmpeg 7.1 build.")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text("License: GNU Lesser General Public License v2.1 or later.")
                            .font(.body)

                        if let ffmpegURL = URL(string: "https://ffmpeg.org") {
                            Link("FFmpeg Project", destination: ffmpegURL)
                                .font(.callout)
                        }

                        if let lgplURL = URL(string: "https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html") {
                            Link("GNU LGPL v2.1 Text", destination: lgplURL)
                                .font(.callout)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("FFmpeg-iOS")
                            .font(.title3.weight(.semibold))

                        Text("The iPad app uses the FFmpeg-iOS and FFmpeg-iOS-Support packages to invoke FFmpeg in-process.")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text("License: GNU Lesser General Public License v2.1 or later.")
                            .font(.body)

                        if let packageURL = URL(string: "https://github.com/kewlbear/FFmpeg-iOS") {
                            Link("FFmpeg-iOS Package", destination: packageURL)
                                .font(.callout)
                        }

                        if let supportURL = URL(string: "https://github.com/kewlbear/FFmpeg-iOS-Support") {
                            Link("FFmpeg-iOS-Support Package", destination: supportURL)
                                .font(.callout)
                        }
                    }

                    Divider()

                    Text("The bundled ffmpeg binary is validated during build to reject GPL-enabled configurations.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
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
        .frame(minWidth: 560, minHeight: 420)
    }
}
