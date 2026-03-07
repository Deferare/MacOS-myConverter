import AppKit
import SwiftUI

struct AboutDetailView: View {
    @ObservedObject var donationStore: DonationStore
    @State private var isShowingOpenSourceLicenses = false

    var body: some View {
        ZStack {
            LiquidGlassBackdrop(tint: .indigo)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 18) {
                        appIconImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 140)
                            .padding(20)
                            .glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: 36, style: .continuous))

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
                    .glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                    Text("Built with SwiftUI & FFmpeg")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("About")
        .backgroundExtensionEffect()
        .task {
            await donationStore.loadProductsIfNeeded()
        }
        .sheet(isPresented: $isShowingOpenSourceLicenses) {
            OpenSourceLicensesSheet(
                isPresented: $isShowingOpenSourceLicenses
            )
        }
        .tint(.indigo)
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
