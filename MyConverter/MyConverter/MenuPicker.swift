import SwiftUI

private enum ConverterSettingMetrics {
    static let rowCornerRadius: CGFloat = 18
    static let controlCornerRadius: CGFloat = 12
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 14
    static let controlHorizontalPadding: CGFloat = 12
    static let controlVerticalPadding: CGFloat = 9
    static let controlColumnWidth: CGFloat = 248
}

private struct ConverterControlBackground: View {
    let isDisabled: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: ConverterSettingMetrics.controlCornerRadius, style: .continuous)
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
                RoundedRectangle(cornerRadius: ConverterSettingMetrics.controlCornerRadius, style: .continuous)
                    .stroke(.white.opacity(isDisabled ? 0.05 : 0.12), lineWidth: 1)
            )
    }
}

struct ConverterSettingRow<Control: View>: View {
    let title: String
    let control: Control

    init(
        _ title: String,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            control
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, ConverterSettingMetrics.rowHorizontalPadding)
        .padding(.vertical, ConverterSettingMetrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: ConverterSettingMetrics.rowCornerRadius, style: .continuous)
            .fill(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: ConverterSettingMetrics.rowCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }
}

struct ConverterSettingsHint: View {
    let text: String

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
        .padding(.horizontal, ConverterSettingMetrics.rowHorizontalPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ConverterSettingMetrics.rowCornerRadius, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: ConverterSettingMetrics.rowCornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct ConverterTextFieldRow: View {
    let title: String
    let prompt: String
    @Binding var text: String

    init(
        _ title: String,
        prompt: String,
        text: Binding<String>
    ) {
        self.title = title
        self.prompt = prompt
        _text = text
    }

    var body: some View {
        ConverterSettingRow(title) {
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, ConverterSettingMetrics.controlHorizontalPadding)
                .padding(.vertical, ConverterSettingMetrics.controlVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(controlBackground)
                .frame(width: ConverterSettingMetrics.controlColumnWidth, alignment: .leading)
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

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.black.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(.white.opacity(0.06), lineWidth: 1)
                            )
                    )

                Text(pathText)
                    .font(.subheadline.weight(hasSelection ? .semibold : .medium))
                    .foregroundStyle(hasSelection ? Color.primary : Color.secondary.opacity(0.82))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onChoose) {
                Text(hasSelection ? "Change" : "Choose")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
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
        }
        .padding(.horizontal, ConverterSettingMetrics.rowHorizontalPadding)
        .padding(.vertical, ConverterSettingMetrics.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .shadow(color: tint.opacity(0.04), radius: 14, x: 0, y: 6)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: ConverterSettingMetrics.rowCornerRadius, style: .continuous)
            .fill(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: ConverterSettingMetrics.rowCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }
}

struct ConverterToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    init(
        _ title: String,
        isOn: Binding<Bool>
    ) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        ConverterSettingRow(title) {
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
    let label: (Option) -> String

    init(
        _ title: String,
        selection: Binding<Option>,
        options: [Option],
        disabledWhenEmpty: Bool = false,
        label: @escaping (Option) -> String
    ) {
        self.title = title
        _selection = selection
        self.options = options
        self.disabledWhenEmpty = disabledWhenEmpty
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
        ConverterSettingRow(title) {
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
                .padding(.horizontal, ConverterSettingMetrics.controlHorizontalPadding)
                .padding(.vertical, ConverterSettingMetrics.controlVerticalPadding)
                .frame(width: ConverterSettingMetrics.controlColumnWidth, alignment: .leading)
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
