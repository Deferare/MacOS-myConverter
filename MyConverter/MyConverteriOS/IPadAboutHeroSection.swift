#if os(iOS)
import SwiftUI

struct IPadAboutHeroSection: View {
    let appVersionText: String

    var body: some View {
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
        Group {
            if let appIconImage = IOSAppIconProvider.primaryIconImage() {
                Image(uiImage: appIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            } else {
                fallbackHeroIcon
            }
        }
        .frame(width: IPadAboutThemeMetrics.heroIconSize, height: IPadAboutThemeMetrics.heroIconSize)
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }

    private var fallbackHeroIcon: some View {
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
}
#endif
