import AppKit
import StoreKit
import SwiftUI

struct AboutDetailView: View {
    @ObservedObject var donationStore: DonationStore
    @State private var isShowingOpenSourceLicenses = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 20) {
                    appIconImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)

                    VStack(spacing: 8) {
                        Text("MyConverter")
                            .font(.system(size: 36, weight: .black))

                        Text(appVersionText)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 60)

                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        aboutSection(title: "Developer", value: "JiHoon K (Deferare)")
                        Divider()
                        aboutSection(title: "Contact", value: "deferare@icloud.com", isLink: true)
                        Divider()
                        aboutSection(title: "License", value: "© 2026 Deferare. All rights reserved.")
                    }

                    Button("Open Source Licenses") {
                        isShowingOpenSourceLicenses = true
                    }
                    .buttonStyle(.link)
                    .font(.subheadline.weight(.medium))

                    Divider()

                    Text("Support Development")
                        .font(.headline)

                    Text("MyConverter is a labor of love. If you find it useful, consider supporting its continued development.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if donationStore.isLoadingProducts {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading support options...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if donationStore.products.isEmpty {
                        Button("Reload Support Options") {
                            Task {
                                await donationStore.loadProducts()
                            }
                        }
                        .buttonStyle(.bordered)
                    } else {
                        HStack(spacing: 12) {
                            ForEach(donationStore.products.sorted(by: { $0.price < $1.price }), id: \.id) { product in
                                Button {
                                    Task {
                                        await donationStore.purchase(product)
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(donationStore.suggestedAmountText(for: product.id))
                                            .font(.subheadline.weight(.bold))
                                        Text(product.displayPrice)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        if donationStore.purchasingProductID == product.id {
                                            ProgressView()
                                                .controlSize(.small)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                }
                                .buttonStyle(.bordered)
                                .disabled(
                                    donationStore.isLoadingProducts ||
                                    (donationStore.purchasingProductID != nil && donationStore.purchasingProductID != product.id)
                                )
                            }
                        }

                        Text("Thank you for your support!")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if let statusMessage = donationStore.statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(donationStore.statusIsError ? .red : .secondary)
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.primary.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                )

                Text("Built with SwiftUI & FFmpeg")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("About")
        .task {
            await donationStore.loadProductsIfNeeded()
        }
        .sheet(isPresented: $isShowingOpenSourceLicenses) {
            openSourceLicensesSheet
        }
    }

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

    private var appVersionText: String {
        guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !shortVersion.isEmpty else {
            return "Version"
        }
        return "Version \(shortVersion)"
    }

    private var appIconImage: Image {
        if let image = NSImage(named: "AppIcon") {
            return Image(nsImage: image)
        }
        return Image(systemName: "circle.hexagonpath.fill")
    }

    private var openSourceLicensesSheet: some View {
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
                        isShowingOpenSourceLicenses = false
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}
