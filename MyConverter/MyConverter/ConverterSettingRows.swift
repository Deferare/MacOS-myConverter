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

struct ConverterTextFieldRow: View {
    let title: String
    let prompt: String
    let showsDivider: Bool
    @Binding var text: String
    @Environment(\.converterSettingMetrics) private var metrics

    init(
        _ title: String,
        prompt: String,
        showsDivider: Bool = true,
        text: Binding<String>
    ) {
        self.title = title
        self.prompt = prompt
        self.showsDivider = showsDivider
        _text = text
    }

    var body: some View {
        ConverterSettingRow(title, showsDivider: showsDivider) {
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, metrics.controlHorizontalPadding)
                .padding(.vertical, metrics.controlVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ConverterControlBackground(isDisabled: false))
                .converterControlFrame(using: metrics)
        }
    }
}

struct OutputFolderSelectionRow: View {
    let pathText: String
    let hasSelection: Bool
    let tint: Color
    let isDisabled: Bool
    let onChoose: () -> Void
    @Environment(\.converterSettingMetrics) private var metrics

    var body: some View {
        Group {
            if metrics.stacksControlsVertically {
                VStack(alignment: .leading, spacing: metrics.rowSpacing) {
                    pathSummary
                    chooseButton
                }
            } else {
                HStack(spacing: metrics.rowSpacing) {
                    pathSummary
                    chooseButton
                }
            }
        }
        .padding(.horizontal, metrics.rowHorizontalPadding)
        .padding(.vertical, metrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
    }

    private var pathSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: metrics.folderIconSize, height: metrics.folderIconSize)
                .background(
                    RoundedRectangle(cornerRadius: metrics.folderIconCornerRadius, style: .continuous)
                        .fill(.black.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: metrics.folderIconCornerRadius, style: .continuous)
                                .stroke(.white.opacity(0.06), lineWidth: 1)
                        )
                )

            Text(pathText)
                .font(.subheadline.weight(hasSelection ? .semibold : .medium))
                .foregroundStyle(hasSelection ? Color.primary : Color.secondary.opacity(0.82))
                .lineLimit(metrics.stacksControlsVertically ? 3 : 1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chooseButton: some View {
        Button(action: onChoose) {
            Text(hasSelection ? "Change" : "Choose")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, metrics.chooseButtonHorizontalPadding)
                .padding(.vertical, metrics.chooseButtonVerticalPadding)
                .background(
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.04))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.085), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: metrics.stacksControlsVertically ? .infinity : nil, alignment: .leading)
    }
}

struct ConverterToggleRow: View {
    let title: String
    let showsDivider: Bool
    @Binding var isOn: Bool

    init(
        _ title: String,
        showsDivider: Bool = true,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.showsDivider = showsDivider
        _isOn = isOn
    }

    var body: some View {
        ConverterSettingRow(title, showsDivider: showsDivider) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
