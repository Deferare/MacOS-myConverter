#if os(iOS)
import SwiftUI

private enum IPadAboutThemeMetrics {
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 20
    static let panelCornerRadius: CGFloat = 28
    static let heroIconSize: CGFloat = 132
    static let heroSymbolSize: CGFloat = 44
}

struct IPadAboutView: View {
    @ObservedObject var donationStore: DonationStore
    @State private var isShowingLicenses = false

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    aboutHeroCard

                    DonationSupportSection(donationStore: donationStore)

                    AboutInfoSection {
                        isShowingLicenses = true
                    }

                    Text("Built with SwiftUI & FFmpeg")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, IPadAboutThemeMetrics.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, IPadAboutThemeMetrics.verticalPadding)
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("About")
        .task {
            await donationStore.loadProductsIfNeeded()
        }
        .sheet(isPresented: $isShowingLicenses) {
            OpenSourceLicensesSheet(isPresented: $isShowingLicenses)
        }
        .tint(.blue)
    }

    private var aboutHeroCard: some View {
        IPadAboutPanelCard {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) {
                    heroIcon
                    heroDetails
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 18) {
                    heroIcon
                    heroDetails
                }
            }
        }
    }

    private var heroIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .blue.opacity(0.42),
                            .teal.opacity(0.30),
                            .white.opacity(0.16),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 1)
                )

            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: IPadAboutThemeMetrics.heroSymbolSize, weight: .black))
                .foregroundStyle(.white.opacity(0.96))
        }
        .frame(width: IPadAboutThemeMetrics.heroIconSize, height: IPadAboutThemeMetrics.heroIconSize)
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }

    private var heroDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MyConverter")
                .font(.system(size: 34, weight: .black, design: .rounded))

            Text("Personal Media Tool")
                .font(.headline)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    versionBadge
                    tagline
                }

                VStack(alignment: .leading, spacing: 8) {
                    versionBadge
                    tagline
                }
            }
        }
    }

    private var versionBadge: some View {
        Text(appVersionText)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }

    private var tagline: some View {
        Text("Built for fast local media conversion")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var appVersionText: String {
        guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !shortVersion.isEmpty else {
            return "Version"
        }

        return "Version \(shortVersion)"
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.20))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 240, y: -220)

            Circle()
                .fill(Color.cyan.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -220, y: 260)

            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 420, height: 220)
                .blur(radius: 120)
                .offset(x: -100, y: -250)
        }
    }
}

private struct IPadAboutPanelCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: IPadAboutThemeMetrics.panelCornerRadius, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: IPadAboutThemeMetrics.panelCornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }
}
#endif
