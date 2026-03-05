import SwiftUI

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

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options) { option in
                Text(label(option)).tag(option)
            }
        }
        .pickerStyle(.menu)
        .disabled(disabledWhenEmpty && options.isEmpty)
    }
}
