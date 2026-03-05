import AppKit
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
                    AboutInfoSection(
                        onOpenLicenses: {
                            isShowingOpenSourceLicenses = true
                        }
                    )

                    DonationSupportSection(donationStore: donationStore)
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
            OpenSourceLicensesSheet(
                isPresented: $isShowingOpenSourceLicenses
            )
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
}
