import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConverterDetailContainer<InputArea: View, FormSections: View, Controls: View>: View {
    let title: String
    @Binding var isDropTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    let inputArea: InputArea
    let formSections: FormSections
    let controls: Controls

    init(
        title: String,
        isDropTargeted: Binding<Bool>,
        onDrop: @escaping ([NSItemProvider]) -> Bool,
        @ViewBuilder inputArea: () -> InputArea,
        @ViewBuilder formSections: () -> FormSections,
        @ViewBuilder controls: () -> Controls
    ) {
        self.title = title
        _isDropTargeted = isDropTargeted
        self.onDrop = onDrop
        self.inputArea = inputArea()
        self.formSections = formSections()
        self.controls = controls()
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                inputArea
                    .padding(24)

                Form {
                    formSections
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            controls
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.primary.opacity(0.05)),
                    alignment: .top
                )
        }
        .navigationTitle(title)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onDrop)
    }
}

struct ConverterInputArea: View {
    let isDropTargeted: Bool
    let selectedURLs: [URL]
    let isConverting: Bool
    let systemImage: String
    let dropPlaceholder: String
    let fileDropAreaHeight: CGFloat
    @Binding var draggedSelectedFileURL: URL?
    let onImport: () -> Void
    let onClear: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    var body: some View {
        Group {
            if !isDropTargeted, !selectedURLs.isEmpty {
                SelectedFilesView(
                    urls: selectedURLs,
                    systemImage: systemImage,
                    isConverting: isConverting,
                    fileDropAreaHeight: fileDropAreaHeight,
                    draggedSelectedFileURL: $draggedSelectedFileURL,
                    onImport: onImport,
                    onClear: onClear,
                    onReorder: onReorder
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                DropFileView(
                    isDropTargeted: isDropTargeted,
                    placeholder: dropPlaceholder,
                    fileDropAreaHeight: fileDropAreaHeight,
                    action: onImport
                )
                .transition(.scale(scale: 0.98).combined(with: .opacity))
            }
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

struct ConverterFormSections<SettingsContent: View>: View {
    let isConverting: Bool
    let outputURLs: [URL]
    let settingsContent: SettingsContent

    init(
        isConverting: Bool,
        outputURLs: [URL],
        @ViewBuilder settingsContent: () -> SettingsContent
    ) {
        self.isConverting = isConverting
        self.outputURLs = outputURLs
        self.settingsContent = settingsContent()
    }

    var body: some View {
        Section("Output Settings") {
            settingsContent
        }
        .disabled(isConverting)

        OutputFilesSection(urls: outputURLs)
    }
}

struct AudioModeAndRatePickers: View {
    @Binding var modeSelection: AudioModeOption
    @Binding var sampleRateSelection: SampleRateOption
    @Binding var bitRateSelection: AudioBitRateOption
    let showSampleRate: Bool
    let showBitRate: Bool

    var body: some View {
        MenuPicker(
            "Audio Mode",
            selection: $modeSelection,
            options: Array(AudioModeOption.allCases),
            label: { $0.rawValue }
        )

        if showSampleRate {
            MenuPicker(
                "Sample Rate",
                selection: $sampleRateSelection,
                options: Array(SampleRateOption.allCases),
                label: { $0.rawValue }
            )
        }

        if showBitRate {
            MenuPicker(
                "Audio Bit Rate",
                selection: $bitRateSelection,
                options: Array(AudioBitRateOption.allCases),
                label: { $0.rawValue }
            )
        }
    }
}

struct ConversionControlBar: View {
    let statusMessage: String
    let statusColor: Color
    let progress: Double
    let progressText: String
    let progressTint: Color
    let isConverting: Bool
    let canConvert: Bool
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text(statusMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)

                    Spacer()

                    Text(progressText)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(progressTint)
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .clipShape(Capsule())
                    .animation(.spring(), value: progress)
            }

            Button {
                if isConverting {
                    onCancel()
                } else {
                    onStart()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isConverting ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .black))
                    Text(isConverting ? "Cancel" : "Start Conversion")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(minWidth: 150, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isConverting ? false : !canConvert)
            .shadow(
                color: (isConverting || canConvert) ? Color.accentColor.opacity(0.2) : .clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
    }
}

extension ContentViewModel.ConversionStatusLevel {
    var color: Color {
        switch self {
        case .normal:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
