import SwiftUI

private enum AboutThemeMetrics {
    static let cardCornerRadius: CGFloat = 28
    static let rowCornerRadius: CGFloat = 20
    static let rowIconSize: CGFloat = 38
}

struct AboutPanelCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AboutThemeMetrics.cardCornerRadius, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: AboutThemeMetrics.cardCornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }
}

struct AboutSectionHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(false), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct AboutRowCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: AboutThemeMetrics.rowCornerRadius, style: .continuous)
            .fill(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: AboutThemeMetrics.rowCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }
}

struct AboutMetadataRow: View {
    let title: String
    let value: String
    let systemImage: String
    var trailingSystemImage: String? = nil
    var emphasizesValue = false

    var body: some View {
        AboutRowCard {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: AboutThemeMetrics.rowIconSize, height: AboutThemeMetrics.rowIconSize)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.05))
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.08), lineWidth: 1)
                            )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(value)
                        .font(.body.weight(.medium))
                        .foregroundStyle(emphasizesValue ? Color.accentColor : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct AboutInlineStatusRow: View {
    let title: String
    let message: String
    var isError = false
    var showsProgress = false

    var body: some View {
        AboutRowCard {
            HStack(spacing: 12) {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isError ? .orange : .secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(isError ? .orange : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }
}
