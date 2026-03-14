import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaConverterInputSectionView: View, Equatable {
    let renderState: ContentViewModel.ConverterRenderState
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat
    let onImport: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    private let fileSelectionAnimation: Animation = .easeOut(duration: 0.22)

    static func == (lhs: MediaConverterInputSectionView, rhs: MediaConverterInputSectionView) -> Bool {
        lhs.renderState == rhs.renderState &&
            lhs.isDropTargeted == rhs.isDropTargeted &&
            lhs.fileDropAreaHeight == rhs.fileDropAreaHeight
    }

    var body: some View {
        let _ = PerformanceSignpost.event("InputSectionRender")

        UnifiedFileListView(
            state: renderState.selectedFileListState,
            dropPlaceholder: "Drop Files Here",
            fileDropAreaHeight: fileDropAreaHeight,
            isDropTargeted: isDropTargeted,
            inputHeaderState: renderState.inputHeaderState,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: onImport,
            onReorder: onReorder
        )
        .animation(fileSelectionAnimation, value: renderState.selectedFileListState.selectedURLs.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTargeted)
    }
}

struct MediaConverterDetailView<FormSections: View>: View {
    let kind: ContentViewModel.MediaKind
    let renderState: ContentViewModel.ConverterRenderState
    @Binding var isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat
    let onDrop: ([NSItemProvider]) -> Bool
    let onImport: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void
    let onClear: () -> Void
    let onPrimaryAction: () -> Void
    let formSections: FormSections
    private let fileSelectionAnimation: Animation = .easeOut(duration: 0.22)

    private var toolbarUtilityTint: Color {
        .white.opacity(0.14)
    }

    init(
        kind: ContentViewModel.MediaKind,
        renderState: ContentViewModel.ConverterRenderState,
        isDropTargeted: Binding<Bool>,
        draggedSelectedFileURL: Binding<URL?>,
        fileDropAreaHeight: CGFloat,
        onDrop: @escaping ([NSItemProvider]) -> Bool,
        onImport: @escaping () -> Void,
        onReorder: @escaping (_ draggedURL: URL, _ targetURL: URL) -> Void,
        onClear: @escaping () -> Void,
        onPrimaryAction: @escaping () -> Void,
        @ViewBuilder formSections: () -> FormSections
    ) {
        self.kind = kind
        self.renderState = renderState
        _isDropTargeted = isDropTargeted
        _draggedSelectedFileURL = draggedSelectedFileURL
        self.fileDropAreaHeight = fileDropAreaHeight
        self.onDrop = onDrop
        self.onImport = onImport
        self.onReorder = onReorder
        self.onClear = onClear
        self.onPrimaryAction = onPrimaryAction
        self.formSections = formSections()
    }

    var body: some View {
        ZStack {
            MediaKindBackdrop(kind: kind)
                .equatable()
                .ignoresSafeArea()

            ConverterDetailContainer(
                screenState: renderState.screenState,
                isDropTargeted: $isDropTargeted,
                onDrop: onDrop,
                inputArea: {
                    MediaConverterInputSectionView(
                        renderState: renderState,
                        isDropTargeted: isDropTargeted,
                        draggedSelectedFileURL: $draggedSelectedFileURL,
                        fileDropAreaHeight: fileDropAreaHeight,
                        onImport: onImport,
                        onReorder: onReorder
                    )
                    .equatable()
                },
                formSections: {
                    formSections
                }
            )
        }
        .navigationTitle(kind.converterTitle)
        .toolbar {
            MediaConverterToolbarContent(
                kind: kind,
                screenState: renderState.screenState,
                utilityTint: toolbarUtilityTint,
                clearAnimation: fileSelectionAnimation,
                onClear: onClear,
                onImport: onImport,
                onPrimaryAction: onPrimaryAction
            )
        }
        .backgroundExtensionEffect()
        .tint(kind.liquidGlassTint)
    }
}
