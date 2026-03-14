import SwiftUI

private enum AboutThemeMetrics {
    static let cardCornerRadius: CGFloat = 28
    static let rowIconSize: CGFloat = 38
    static let rowVerticalPadding: CGFloat = 14
    static let dividerLeadingInset: CGFloat = 52
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

struct AboutSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, AboutThemeMetrics.dividerLeadingInset)
    }
}

struct AboutMetadataRow: View {
    let title: String
    let value: String
    let systemImage: String
    var trailingSystemImage: String? = nil
    var emphasizesValue = false

    var body: some View {
        HStack(spacing: 14) {
            rowIcon(symbolName: systemImage)

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, AboutThemeMetrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowIcon(symbolName: String) -> some View {
        Image(systemName: symbolName)
            .font(.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: AboutThemeMetrics.rowIconSize, height: AboutThemeMetrics.rowIconSize)
            .background(
                Circle()
                    .fill(.white.opacity(0.12))
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.20), lineWidth: 1)
                    )
            )
    }
}

struct AboutInlineStatusRow: View {
    let title: String
    let message: String
    var isError = false
    var showsProgress = false

    var body: some View {
        HStack(spacing: 12) {
            statusLeadingView

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isError ? .orange : .primary)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(isError ? .orange.opacity(0.8) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(isError ? 16 : 0)
        .padding(.vertical, isError ? 0 : AboutThemeMetrics.rowVerticalPadding)
        .background(
            Group {
                if isError {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusLeadingView: some View {
        if showsProgress {
            ProgressView()
                .controlSize(.small)
                .frame(width: AboutThemeMetrics.rowIconSize, height: AboutThemeMetrics.rowIconSize)
        } else {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(isError ? .orange : .secondary)
                .frame(width: AboutThemeMetrics.rowIconSize, height: AboutThemeMetrics.rowIconSize)
        }
    }
}
