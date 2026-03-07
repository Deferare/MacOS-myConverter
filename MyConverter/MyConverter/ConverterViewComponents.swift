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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                controls
            }
        }
        .navigationTitle(title)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: onDrop)
    }
}

struct ConverterInputArea: View {
    let isDropTargeted: Bool
    let selectedURLs: [URL]
    let outputURLsBySourceID: [String: URL]
    let processedSourceIDs: Set<String>
    let isConverting: Bool
    let currentBatchIndex: Int
    let currentItemProgress: Double
    let systemImage: String
    let dropPlaceholder: String
    let fileDropAreaHeight: CGFloat
    @Binding var draggedSelectedFileURL: URL?
    let onImport: () -> Void
    let onClear: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    var body: some View {
        UnifiedFileListView(
            sourceURLs: selectedURLs,
            outputURLsBySourceID: outputURLsBySourceID,
            processedSourceIDs: processedSourceIDs,
            systemImage: systemImage,
            dropPlaceholder: dropPlaceholder,
            isConverting: isConverting,
            currentBatchIndex: currentBatchIndex,
            currentItemProgress: currentItemProgress,
            fileDropAreaHeight: fileDropAreaHeight,
            isDropTargeted: isDropTargeted,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: onImport,
            onClear: onClear,
            onReorder: onReorder
        )
    }
}

struct ConverterFormSections<SettingsContent: View>: View {
    let isConverting: Bool
    let settingsContent: SettingsContent

    init(
        isConverting: Bool,
        @ViewBuilder settingsContent: () -> SettingsContent
    ) {
        self.isConverting = isConverting
        self.settingsContent = settingsContent()
    }

    var body: some View {
        Section("Output Settings") {
            settingsContent
        }
        .disabled(isConverting)
    }
}

struct MediaConverterInputSectionView: View {
    @ObservedObject var viewModel: ContentViewModel
    let kind: ContentViewModel.MediaKind
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat

    private let fileSelectionAnimation: Animation = .easeOut(duration: 0.22)

    var body: some View {
        let state = viewModel.selectedFileListState(for: kind)

        ConverterInputArea(
            isDropTargeted: isDropTargeted,
            selectedURLs: state.selectedURLs,
            outputURLsBySourceID: state.outputURLsBySourceID,
            processedSourceIDs: state.processedSourceIDs,
            isConverting: state.isConverting,
            currentBatchIndex: state.currentBatchIndex,
            currentItemProgress: state.currentItemProgress,
            systemImage: kind.inputSystemImage,
            dropPlaceholder: "Drop Files Here",
            fileDropAreaHeight: fileDropAreaHeight,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: {
                viewModel.requestFileImport()
            },
            onClear: {
                withAnimation(fileSelectionAnimation) {
                    viewModel.clearSelectedSource(for: kind)
                }
            },
            onReorder: { draggedURL, targetURL in
                viewModel.moveSelectedSource(from: draggedURL, to: targetURL, for: kind)
            }
        )
        .animation(fileSelectionAnimation, value: state.selectedURLs.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTargeted)
    }
}

struct MediaConversionControlsView: View {
    @ObservedObject var viewModel: ContentViewModel
    let kind: ContentViewModel.MediaKind

    var body: some View {
        let state = viewModel.conversionControlState(for: kind)

        ConversionToolbarButton(
            isConverting: state.isConverting,
            canConvert: state.canConvert,
            onStart: { viewModel.startConversion(for: kind) },
            onCancel: { viewModel.cancelConversion(for: kind) }
        )
    }
}

struct MediaConverterDetailView<FormSections: View>: View {
    @ObservedObject var viewModel: ContentViewModel
    let kind: ContentViewModel.MediaKind
    @Binding var isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat
    let formSections: FormSections

    init(
        viewModel: ContentViewModel,
        kind: ContentViewModel.MediaKind,
        isDropTargeted: Binding<Bool>,
        draggedSelectedFileURL: Binding<URL?>,
        fileDropAreaHeight: CGFloat,
        @ViewBuilder formSections: () -> FormSections
    ) {
        self.viewModel = viewModel
        self.kind = kind
        _isDropTargeted = isDropTargeted
        _draggedSelectedFileURL = draggedSelectedFileURL
        self.fileDropAreaHeight = fileDropAreaHeight
        self.formSections = formSections()
    }

    var body: some View {
        ConverterDetailContainer(
            title: kind.converterTitle,
            isDropTargeted: $isDropTargeted,
            onDrop: { providers in
                viewModel.handleDrop(providers: providers, for: kind)
            },
            inputArea: {
                MediaConverterInputSectionView(
                    viewModel: viewModel,
                    kind: kind,
                    isDropTargeted: isDropTargeted,
                    draggedSelectedFileURL: $draggedSelectedFileURL,
                    fileDropAreaHeight: fileDropAreaHeight
                )
            },
            formSections: {
                formSections
            },
            controls: {
                MediaConversionControlsView(viewModel: viewModel, kind: kind)
            }
        )
    }
}
