import AppKit
import SwiftUI

struct AboutDetailView: View {
    @ObservedObject var donationStore: DonationStore
    @State private var isShowingOpenSourceLicenses = false

    var body: some View {
        ZStack {
            LiquidGlassBackdrop(tint: .blue)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    aboutHeroCard

                    DonationSupportSection(donationStore: donationStore)

                    AboutInfoSection(
                        onOpenLicenses: {
                            isShowingOpenSourceLicenses = true
                        }
                    )

                    Text("Built with SwiftUI & FFmpeg")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: 960)
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
        .tint(.blue)
    }

    private var aboutHeroCard: some View {
        AboutPanelCard {
            HStack(spacing: 24) {
                appIconImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("MyConverter")
                        .font(.system(size: 34, weight: .black))

                    Text("Personal Media Tool")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(appVersionText)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassEffect(.regular.interactive(false), in: Capsule())

                        Text("Built for fast local media conversion")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
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
}
