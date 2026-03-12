import SwiftUI

struct ConverterSettingMetrics {
    let rowCornerRadius: CGFloat
    let controlCornerRadius: CGFloat
    let rowHorizontalPadding: CGFloat
    let rowVerticalPadding: CGFloat
    let controlHorizontalPadding: CGFloat
    let controlVerticalPadding: CGFloat
    let controlColumnWidth: CGFloat
    let sectionSpacing: CGFloat
    let hintVerticalPadding: CGFloat
    let folderIconSize: CGFloat
    let folderIconCornerRadius: CGFloat
    let chooseButtonHorizontalPadding: CGFloat
    let chooseButtonVerticalPadding: CGFloat
    let rowSpacing: CGFloat
    let stacksControlsVertically: Bool

    static let regular = ConverterSettingMetrics(
        rowCornerRadius: 18,
        controlCornerRadius: 12,
        rowHorizontalPadding: 16,
        rowVerticalPadding: 14,
        controlHorizontalPadding: 12,
        controlVerticalPadding: 9,
        controlColumnWidth: 248,
        sectionSpacing: 14,
        hintVerticalPadding: 12,
        folderIconSize: 28,
        folderIconCornerRadius: 10,
        chooseButtonHorizontalPadding: 16,
        chooseButtonVerticalPadding: 8,
        rowSpacing: 16,
        stacksControlsVertically: false
    )

    static let compact = ConverterSettingMetrics(
        rowCornerRadius: 17,
        controlCornerRadius: 11,
        rowHorizontalPadding: 15,
        rowVerticalPadding: 12,
        controlHorizontalPadding: 11,
        controlVerticalPadding: 8,
        controlColumnWidth: 236,
        sectionSpacing: 12,
        hintVerticalPadding: 11,
        folderIconSize: 26,
        folderIconCornerRadius: 9,
        chooseButtonHorizontalPadding: 14,
        chooseButtonVerticalPadding: 7,
        rowSpacing: 14,
        stacksControlsVertically: false
    )

    static let phone = ConverterSettingMetrics(
        rowCornerRadius: 16,
        controlCornerRadius: 11,
        rowHorizontalPadding: 14,
        rowVerticalPadding: 12,
        controlHorizontalPadding: 12,
        controlVerticalPadding: 10,
        controlColumnWidth: 236,
        sectionSpacing: 12,
        hintVerticalPadding: 11,
        folderIconSize: 24,
        folderIconCornerRadius: 8,
        chooseButtonHorizontalPadding: 14,
        chooseButtonVerticalPadding: 8,
        rowSpacing: 10,
        stacksControlsVertically: true
    )
}

private struct ConverterSettingMetricsKey: EnvironmentKey {
    static let defaultValue = ConverterSettingMetrics.regular
}

extension EnvironmentValues {
    var converterSettingMetrics: ConverterSettingMetrics {
        get { self[ConverterSettingMetricsKey.self] }
        set { self[ConverterSettingMetricsKey.self] = newValue }
    }
}

extension View {
    func converterSettingMetrics(_ metrics: ConverterSettingMetrics) -> some View {
        environment(\.converterSettingMetrics, metrics)
    }
}

private struct ConverterControlBackground: View {
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

private extension View {
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
                .background(controlBackground)
                .converterControlFrame(using: metrics)
        }
    }

    private var controlBackground: some View {
        ConverterControlBackground(isDisabled: false)
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

struct MenuPicker<Option: Identifiable & Hashable>: View {
    let title: String
    @Binding var selection: Option
    let options: [Option]
    let disabledWhenEmpty: Bool
    let showsDivider: Bool
    let label: (Option) -> String
    @Environment(\.converterSettingMetrics) private var metrics

    init(
        _ title: String,
        selection: Binding<Option>,
        options: [Option],
        disabledWhenEmpty: Bool = false,
        showsDivider: Bool = true,
        label: @escaping (Option) -> String
    ) {
        self.title = title
        _selection = selection
        self.options = options
        self.disabledWhenEmpty = disabledWhenEmpty
        self.showsDivider = showsDivider
        self.label = label
    }

    private var isDisabled: Bool {
        disabledWhenEmpty && options.isEmpty
    }

    private var pickerOptions: [Option] {
        guard !options.contains(selection) else { return options }
        return [selection] + options.filter { $0 != selection }
    }

    var body: some View {
        ConverterSettingRow(title, showsDivider: showsDivider) {
            Menu {
                ForEach(pickerOptions, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        HStack(spacing: 8) {
                            if option == selection {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                            }

                            Text(label(option))
                                .lineLimit(1)
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(label(selection))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isDisabled ? Color.secondary.opacity(0.82) : Color.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(isDisabled ? 0.42 : 0.68))
                }
                .padding(.horizontal, metrics.controlHorizontalPadding)
                .padding(.vertical, metrics.controlVerticalPadding)
                .converterControlFrame(using: metrics)
                .background(ConverterControlBackground(isDisabled: isDisabled))
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(label(selection)))
        }
    }
}
