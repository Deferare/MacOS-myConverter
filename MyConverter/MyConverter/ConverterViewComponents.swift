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

struct DropFileView: View {
    let isDropTargeted: Bool
    let placeholder: String
    let fileDropAreaHeight: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.15) : Color.accentColor.opacity(0.05))
                        .frame(width: 88, height: 88)
                        .blur(radius: isDropTargeted ? 10 : 0)
                        .scaleEffect(isDropTargeted ? 1.15 : 1.0)

                    Circle()
                        .stroke(Color.accentColor.opacity(isDropTargeted ? 0.3 : 0.1), lineWidth: 1)
                        .frame(width: 104, height: 104)
                        .scaleEffect(isDropTargeted ? 1.05 : 1.0)

                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                }

                VStack(spacing: 8) {
                    Text(isDropTargeted ? "Drop to Import" : placeholder)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .primary)

                    Text(isDropTargeted ? "Release to start conversion setup" : "or click to browse local files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: fileDropAreaHeight)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.03) : Color.primary.opacity(0.01))

                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: isDropTargeted ? [] : [4, 4])
                        )
                }
            )
            .contentShape(Rectangle())
            .scaleEffect(isDropTargeted ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDropTargeted)
    }
}

struct SelectedFilesView: View {
    let urls: [URL]
    let systemImage: String
    let isConverting: Bool
    let fileDropAreaHeight: CGFloat
    @Binding var draggedSelectedFileURL: URL?
    let onImport: () -> Void
    let onClear: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text("Selected Files")
                    .font(.headline)

                Text("\(urls.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))

                Spacer()

                if !isConverting {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(urls.enumerated()), id: \.element.path) { index, url in
                        SelectedFileCardView(
                            url: url,
                            order: index + 1,
                            systemImage: systemImage
                        )
                        .onDrag {
                            guard !isConverting else {
                                return NSItemProvider()
                            }
                            draggedSelectedFileURL = url
                            return NSItemProvider(object: NSString(string: url.path))
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: SelectedFileReorderDropDelegate(
                                targetURL: url,
                                urls: urls,
                                draggedURL: $draggedSelectedFileURL,
                                isEnabled: !isConverting,
                                onMove: { draggedURL, targetURL in
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                        onReorder(draggedURL, targetURL)
                                    }
                                }
                            )
                        )
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack {
                Text(isConverting ? "Ready for conversion" : "Ready for conversion · Drag cards to reorder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onImport) {
                    Label("Add Files", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isConverting)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: fileDropAreaHeight, maxHeight: fileDropAreaHeight)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.background.opacity(0.4).shadow(.inner(color: .white.opacity(0.1), radius: 0, x: 0, y: 1)))
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct SelectedFileCardView: View {
    let url: URL
    let order: Int
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 28, height: 28)
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                Text("\(order)")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.6))
            }

            Spacer(minLength: 4)

            Text(url.lastPathComponent)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(url.pathExtension.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                Spacer()
            }
        }
        .padding(12)
        .frame(width: 140, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background.opacity(0.4))
                .background(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

struct OutputFilesSection: View {
    let urls: [URL]

    var body: some View {
        Section("Output Files") {
            if urls.isEmpty {
                Text("Converted files will appear here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(urls.enumerated()), id: \.element.path) { index, url in
                        OutputFileCardView(
                            url: url,
                            order: index + 1
                        )
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

struct OutputFileCardView: View {
    let url: URL
    let order: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(order)")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.05)))

                    Text(url.lastPathComponent)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help("Show in Finder")

                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text("Open")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.background.opacity(0.4))
                .background(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.02), radius: 6, x: 0, y: 3)
    }
}

struct SelectedFileReorderDropDelegate: DropDelegate {
    let targetURL: URL
    let urls: [URL]
    @Binding var draggedURL: URL?
    let isEnabled: Bool
    let onMove: (_ draggedURL: URL, _ targetURL: URL) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && info.hasItemsConforming(to: [UTType.text.identifier])
    }

    func dropEntered(info: DropInfo) {
        guard isEnabled else { return }
        guard let draggedURL else { return }
        guard draggedURL.path != targetURL.path else { return }
        guard urls.contains(where: { $0.path == draggedURL.path }) else { return }
        guard urls.contains(where: { $0.path == targetURL.path }) else { return }

        onMove(draggedURL, targetURL)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isEnabled else { return nil }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedURL = nil
        return isEnabled
    }
}
