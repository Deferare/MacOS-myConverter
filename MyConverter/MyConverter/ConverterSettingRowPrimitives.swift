import SwiftUI

struct ConverterControlBackground: View {
    let isDisabled: Bool
    @Environment(\.converterSettingMetrics) private var metrics

    var body: some View {
        RoundedRectangle(cornerRadius: metrics.controlCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(isDisabled ? 0.03 : 0.09),
                        .white.opacity(isDisabled ? 0.02 : 0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.controlCornerRadius, style: .continuous)
                    .stroke(.white.opacity(isDisabled ? 0.05 : 0.12), lineWidth: 1)
            )
    }
}

private struct ConverterRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
    }
}

extension View {
    @ViewBuilder
    func converterControlFrame(using metrics: ConverterSettingMetrics) -> some View {
        if metrics.stacksControlsVertically {
            self.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            self.frame(width: metrics.controlColumnWidth, alignment: .leading)
        }
    }
}

struct ConverterSettingRow<Control: View>: View {
    let title: String
    let control: Control
    let showsDivider: Bool
    @Environment(\.converterSettingMetrics) private var metrics

    init(
        _ title: String,
        showsDivider: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.showsDivider = showsDivider
        self.control = control()
    }

    var body: some View {
        Group {
            if metrics.stacksControlsVertically {
                VStack(alignment: .leading, spacing: metrics.rowSpacing) {
                    titleLabel
                    control
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: metrics.rowSpacing) {
                    titleLabel
                    control
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, metrics.rowHorizontalPadding)
        .padding(.vertical, metrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if showsDivider {
                ConverterRowDivider()
            }
        }
    }

    private var titleLabel: some View {
        Text(title)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(metrics.stacksControlsVertically ? nil : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ConverterSettingsHint: View {
    let text: String
    var showsDivider = true
    @Environment(\.converterSettingMetrics) private var metrics

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, metrics.rowHorizontalPadding)
        .padding(.vertical, metrics.hintVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            if showsDivider {
                ConverterRowDivider()
            }
        }
    }
}
