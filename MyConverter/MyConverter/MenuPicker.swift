import SwiftUI

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
