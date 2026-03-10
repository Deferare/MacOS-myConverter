import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension ContentViewModel.MediaKind {
    var liquidGlassTint: Color {
        switch self {
        case .video:
            return .blue
        case .image:
            return .orange
        case .audio:
            return .teal
        }
    }
}

struct LiquidGlassBackdrop: View {
    let tint: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .underPageBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 96)
                .offset(x: 240, y: -220)

            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -260, y: 260)

            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 480, height: 220)
                .blur(radius: 120)
                .offset(x: -120, y: -260)
        }
    }
}

struct MediaKindBackdrop: View, Equatable {
    let kind: ContentViewModel.MediaKind

    static func == (lhs: MediaKindBackdrop, rhs: MediaKindBackdrop) -> Bool {
        lhs.kind == rhs.kind
    }

    var body: some View {
        LiquidGlassBackdrop(tint: kind.liquidGlassTint)
    }
}

private struct ConverterPanelCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }
}

struct ConverterSettingsPlaceholder: View {
    var body: some View {
        ConverterPanelCard {
            HStack(spacing: 16) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, height: 42)
                    .glassEffect(.regular.interactive(false), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text("Conversion Settings")
                        .font(.title3.weight(.semibold))

                    Text("Import files to unlock compatible conversion settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ConverterDetailContainer<InputArea: View, FormSections: View>: View {
    let screenState: ContentViewModel.ConverterScreenState
    @Binding var isDropTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    let inputArea: InputArea
    let formSections: FormSections

    init(
        screenState: ContentViewModel.ConverterScreenState,
        isDropTargeted: Binding<Bool>,
        onDrop: @escaping ([NSItemProvider]) -> Bool,
        @ViewBuilder inputArea: () -> InputArea,
        @ViewBuilder formSections: () -> FormSections
    ) {
        self.screenState = screenState
        _isDropTargeted = isDropTargeted
        self.onDrop = onDrop
        self.inputArea = inputArea()
        self.formSections = formSections()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                inputArea

                if screenState.showsSettings {
                    ConverterPanelCard {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Conversion Settings")
                                .font(.headline)

                            VStack(spacing: 14) {
                                formSections
                            }
                        }
                    }
                } else {
                    ConverterSettingsPlaceholder()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
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
    let dropPlaceholder: String
    let fileDropAreaHeight: CGFloat
    let inputHeaderState: ContentViewModel.ConverterInputHeaderState
    let themeTint: Color
    @Binding var draggedSelectedFileURL: URL?
    let onImport: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    var body: some View {
        UnifiedFileListView(
            sourceURLs: selectedURLs,
            outputURLsBySourceID: outputURLsBySourceID,
            processedSourceIDs: processedSourceIDs,
            dropPlaceholder: dropPlaceholder,
            isConverting: isConverting,
            currentBatchIndex: currentBatchIndex,
            currentItemProgress: currentItemProgress,
            fileDropAreaHeight: fileDropAreaHeight,
            isDropTargeted: isDropTargeted,
            inputHeaderState: inputHeaderState,
            themeTint: themeTint,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: onImport,
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
        VStack(spacing: 14) {
            settingsContent
        }
        .disabled(isConverting)
    }
}

struct MediaConverterInputSectionView: View, Equatable {
    let kind: ContentViewModel.MediaKind
    let state: ContentViewModel.SelectedFileListState
    let inputHeaderState: ContentViewModel.ConverterInputHeaderState
    let isDropTargeted: Bool
    @Binding var draggedSelectedFileURL: URL?
    let fileDropAreaHeight: CGFloat
    let onImport: () -> Void
    let onReorder: (_ draggedURL: URL, _ targetURL: URL) -> Void

    private let fileSelectionAnimation: Animation = .easeOut(duration: 0.22)

    static func == (lhs: MediaConverterInputSectionView, rhs: MediaConverterInputSectionView) -> Bool {
        lhs.kind == rhs.kind &&
            lhs.state == rhs.state &&
            lhs.inputHeaderState == rhs.inputHeaderState &&
            lhs.isDropTargeted == rhs.isDropTargeted &&
            lhs.fileDropAreaHeight == rhs.fileDropAreaHeight
    }

    var body: some View {
        let _ = PerformanceSignpost.event("InputSectionRender")

        ConverterInputArea(
            isDropTargeted: isDropTargeted,
            selectedURLs: state.selectedURLs,
            outputURLsBySourceID: state.outputURLsBySourceID,
            processedSourceIDs: state.processedSourceIDs,
            isConverting: state.isConverting,
            currentBatchIndex: state.currentBatchIndex,
            currentItemProgress: state.currentItemProgress,
            dropPlaceholder: "Drop Files Here",
            fileDropAreaHeight: fileDropAreaHeight,
            inputHeaderState: inputHeaderState,
            themeTint: kind.liquidGlassTint,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            onImport: onImport,
            onReorder: onReorder
        )
        .animation(fileSelectionAnimation, value: state.selectedURLs.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDropTargeted)
    }
}

struct MediaConverterDetailView<FormSections: View>: View {
    let kind: ContentViewModel.MediaKind
    let screenState: ContentViewModel.ConverterScreenState
    let inputHeaderState: ContentViewModel.ConverterInputHeaderState
    let selectedFileListState: ContentViewModel.SelectedFileListState
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
        screenState: ContentViewModel.ConverterScreenState,
        inputHeaderState: ContentViewModel.ConverterInputHeaderState,
        selectedFileListState: ContentViewModel.SelectedFileListState,
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
        self.screenState = screenState
        self.inputHeaderState = inputHeaderState
        self.selectedFileListState = selectedFileListState
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
                screenState: screenState,
                isDropTargeted: $isDropTargeted,
                onDrop: onDrop,
                inputArea: {
                    MediaConverterInputSectionView(
                        kind: kind,
                        state: selectedFileListState,
                        inputHeaderState: inputHeaderState,
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
            converterToolbar(screenState: screenState)
        }
        .backgroundExtensionEffect()
        .tint(kind.liquidGlassTint)
    }

    @ToolbarContentBuilder
    private func converterToolbar(
        screenState: ContentViewModel.ConverterScreenState
    ) -> some ToolbarContent {
        if screenState.selectedFileCount > 0 {
            ToolbarItemGroup(placement: .primaryAction) {
                if !screenState.isConverting {
                    Button {
                        withAnimation(fileSelectionAnimation) {
                            onClear()
                        }
                    } label: {
                        Label("Clear Files", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .tint(toolbarUtilityTint)
                    .help("Clear Files")

                    Button("Add Files", systemImage: "plus") {
                        onImport()
                    }
                    .tint(toolbarUtilityTint)
                }

                Button {
                    onPrimaryAction()
                } label: {
                    Text(screenState.primaryActionTitle)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(kind.liquidGlassTint)
                .disabled(!screenState.isConverting && !screenState.canConvert)
            }
        }
    }
}
