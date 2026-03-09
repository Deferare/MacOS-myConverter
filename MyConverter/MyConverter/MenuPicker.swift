import SwiftUI

private enum ConverterSettingMetrics {
    static let rowCornerRadius: CGFloat = 18
    static let controlCornerRadius: CGFloat = 12
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 14
    static let controlHorizontalPadding: CGFloat = 12
    static let controlVerticalPadding: CGFloat = 9
    static let minimumControlWidth: CGFloat = 180
    static let maximumControlWidth: CGFloat = 280
    static let maximumPopoverHeight: CGFloat = 360
    static let optionRowHeightEstimate: CGFloat = 40
    static let optionSpacing: CGFloat = 6
    static let optionListVerticalPadding: CGFloat = 20
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
                .frame(maxWidth: .infinity, alignment: .leading)

            control
                .frame(
                    minWidth: ConverterSettingMetrics.minimumControlWidth,
                    maxWidth: ConverterSettingMetrics.maximumControlWidth,
                    alignment: .trailing
                )
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
        }
    }

    private var controlBackground: some View {
        RoundedRectangle(cornerRadius: ConverterSettingMetrics.controlCornerRadius, style: .continuous)
            .fill(.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: ConverterSettingMetrics.controlCornerRadius, style: .continuous)
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
    @State private var isPresentingOptions = false

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

    private var popoverHeight: CGFloat {
        let rowCount = CGFloat(options.count)
        let spacingCount = CGFloat(max(options.count - 1, 0))
        let contentHeight =
            (rowCount * ConverterSettingMetrics.optionRowHeightEstimate) +
            (spacingCount * ConverterSettingMetrics.optionSpacing) +
            ConverterSettingMetrics.optionListVerticalPadding

        return min(contentHeight, ConverterSettingMetrics.maximumPopoverHeight)
    }

    var body: some View {
        ConverterSettingRow(title) {
            Button {
                guard !isDisabled else { return }
                isPresentingOptions.toggle()
            } label: {
                HStack(spacing: 10) {
                    Text(label(selection))
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, ConverterSettingMetrics.controlHorizontalPadding)
                .padding(.vertical, ConverterSettingMetrics.controlVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(controlBackground)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1)
            .popover(isPresented: $isPresentingOptions, arrowEdge: .top) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: ConverterSettingMetrics.optionSpacing) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                selection = option
                                isPresentingOptions = false
                            } label: {
                                HStack(spacing: 12) {
                                    Text(label(option))
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if option == selection {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(optionBackground(isSelected: option == selection))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(10)
                }
                .frame(
                    minWidth: ConverterSettingMetrics.minimumControlWidth,
                    maxWidth: ConverterSettingMetrics.maximumControlWidth,
                    maxHeight: popoverHeight,
                    alignment: .leading
                )
            }
        }
    }

    private var controlBackground: some View {
        RoundedRectangle(cornerRadius: ConverterSettingMetrics.controlCornerRadius, style: .continuous)
            .fill(.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: ConverterSettingMetrics.controlCornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }

    private func optionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isSelected ? .white.opacity(0.08) : .clear)
    }
}
