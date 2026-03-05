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
