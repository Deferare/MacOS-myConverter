#if os(iOS)
import SwiftUI

enum IPadMediaConverterStyle {
    static let sectionTitleFont = Font.headline.weight(.semibold)
    static let panelCornerRadius: CGFloat = 28
    static let panelPadding: CGFloat = 24
    static let settingsSectionSpacing: CGFloat = 14
}

struct IPadMediaConverterBackground: View {
    let tint: Color

    var body: some View {
        LinearGradient(
            colors: [
                tint.opacity(0.32),
                Color(.systemBackground),
                tint.opacity(0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct IPadMediaConverterPanelBackground: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous)
            .fill(.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.08),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }
}

struct IPadEmptySettingsPanel: View {
    let settingMetrics: ConverterSettingMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversion Settings")
                        .font(IPadMediaConverterStyle.sectionTitleFont)
                    Text("Import files to unlock compatible conversion settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(IPadMediaConverterStyle.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IPadMediaConverterPanelBackground(tint: .clear))
        .overlay(
            RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous))
        .converterSettingMetrics(settingMetrics)
    }
}
#endif
