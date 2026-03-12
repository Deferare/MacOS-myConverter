#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IPadMediaConverterView: View {
    private enum Metrics {
        static let sectionTitleFont = Font.headline.weight(.semibold)
        static let panelCornerRadius: CGFloat = 28
        static let panelPadding: CGFloat = 24
        static let settingsSectionSpacing: CGFloat = 14
    }

    let kind: ContentViewModel.MediaKind
    @ObservedObject var viewModel: ContentViewModel
    @State private var isDropTargeted = false
    @State private var draggedSelectedFileURL: URL?

    private var renderState: ContentViewModel.ConverterRenderState {
        viewModel.converterRenderState(for: kind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if renderState.selectedFileListState.selectedURLs.isEmpty {
                        emptyInputSection
                        emptySettingsSection
                    } else {
                        filesSection
                        settingsSection
                    }
                }
                .padding(20)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .background(background.ignoresSafeArea())
            .toolbar {
                converterToolbar
            }
        }
    }

    private var emptyInputSection: some View {
        Button {
            viewModel.requestFileImport()
        } label: {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(isDropTargeted ? 0.20 : 0.14))
                        .overlay(
                            Circle()
                                .stroke(
                                    isDropTargeted ? kind.liquidGlassTint.opacity(0.34) : .white.opacity(0.10),
                                    lineWidth: isDropTargeted ? 1.6 : 1
                                )
                        )
                        .shadow(color: .black.opacity(0.18), radius: 22, y: 12)

                    Circle()
                        .fill(.white.opacity(isDropTargeted ? 0.24 : 0.20))
                        .frame(width: 56, height: 56)

                    Image(systemName: isDropTargeted ? "arrow.down" : "plus")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white.opacity(0.96))
                }
                .frame(width: 140, height: 140)
                .scaleEffect(isDropTargeted ? 1.03 : 1.0)

                VStack(spacing: 8) {
                    Text(isDropTargeted ? "Drop to Import" : "Drop Files Here")
                        .font(.system(size: 23, weight: .bold, design: .rounded))

                    Text(
                        isDropTargeted
                            ? "Release to add the files to this queue."
                            : "Drop files here or tap anywhere in this area to browse."
                    )
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 430)
        }
        .buttonStyle(.plain)
        .padding(Metrics.panelPadding)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .stroke(isDropTargeted ? kind.liquidGlassTint.opacity(0.45) : .white.opacity(0.10), lineWidth: isDropTargeted ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers, for: kind)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isDropTargeted)
    }

    private var filesSection: some View {
        let selectedURLs = renderState.selectedFileListState.selectedURLs
        let availableURLPaths = Set(selectedURLs.map(\.path))

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Files")
                    .font(Metrics.sectionTitleFont)

                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusTone)
                            .frame(width: 10, height: 10)
                        Text(renderState.inputHeaderState.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(statusTone)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer()

                    if renderState.screenState.isConverting {
                        Text(renderState.inputHeaderState.progressText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(isDropTargeted ? "Release to add files" : "Drag to reorder or drop more files here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(Array(selectedURLs.enumerated()), id: \.element) { index, url in
                    IPadFileRow(
                        kind: kind,
                        url: url,
                        order: index + 1,
                        rowState: renderState.selectedFileListState.rowState(for: url),
                        thumbnailProvider: viewModel.services.thumbnailProvider
                    )
                    .onDrag {
                        guard !renderState.screenState.isConverting else {
                            return NSItemProvider()
                        }

                        draggedSelectedFileURL = url
                        return NSItemProvider(object: NSString(string: url.path))
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: IPadSelectedFileReorderDropDelegate(
                            targetURL: url,
                            availableURLPaths: availableURLPaths,
                            draggedURL: $draggedSelectedFileURL,
                            isEnabled: !renderState.screenState.isConverting,
                            onMove: { draggedURL, targetURL in
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    viewModel.moveSelectedSource(from: draggedURL, to: targetURL, for: kind)
                                }
                            }
                        )
                    )
                }
            }
        }
        .padding(Metrics.panelPadding)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .stroke(isDropTargeted ? kind.liquidGlassTint.opacity(0.45) : .white.opacity(0.10), lineWidth: isDropTargeted ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers, for: kind)
        }
    }

    private var emptySettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversion Settings")
                        .font(Metrics.sectionTitleFont)
                    Text("Import files to unlock compatible conversion settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Metrics.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Metrics.settingsSectionSpacing) {
            Text("Conversion Settings")
                .font(Metrics.sectionTitleFont)

            OutputFolderSelectionRow(
                pathText: viewModel.selectedOutputDirectoryURL(for: kind).map {
                    viewModel.abbreviatedOutputDirectoryPath($0)
                } ?? "No folder selected",
                hasSelection: viewModel.hasSelectedOutputDirectory(for: kind),
                tint: kind.liquidGlassTint,
                isDisabled: renderState.screenState.isConverting,
                onChoose: {
                    Task {
                        await viewModel.chooseOutputDirectory(for: kind)
                    }
                }
            )

            switch kind {
            case .video:
                VideoConverterFormSectionView(
                    state: viewModel.videoFormPresentationState(),
                    bindings: viewModel.videoFormBindings()
                )
            case .image:
                ImageConverterFormSectionView(
                    state: viewModel.imageFormPresentationState(),
                    bindings: viewModel.imageFormBindings()
                )
            case .audio:
                AudioConverterFormSectionView(
                    state: viewModel.audioFormPresentationState(),
                    bindings: viewModel.audioFormBindings()
                )
            }
        }
        .padding(Metrics.panelPadding)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous))
        .converterSettingMetrics(.compact)
    }

    @ToolbarContentBuilder
    private var converterToolbar: some ToolbarContent {
        if renderState.screenState.selectedFileCount > 0 {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !renderState.screenState.isConverting {
                    Button {
                        viewModel.clearSelectedSource(for: kind)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(renderState.selectedFileListState.selectedURLs.isEmpty)

                    Button {
                        viewModel.requestFileImport()
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                Button {
                    if renderState.screenState.isConverting {
                        viewModel.cancelConversion(for: kind)
                    } else {
                        viewModel.startConversion(for: kind)
                    }
                } label: {
                    Text(renderState.screenState.primaryActionTitle)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(kind.liquidGlassTint)
                .disabled(!renderState.screenState.isConverting && !renderState.screenState.canConvert)
            }
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
            .fill(.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                kind.liquidGlassTint.opacity(0.08),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                kind.liquidGlassTint.opacity(0.32),
                Color(.systemBackground),
                kind.liquidGlassTint.opacity(0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var statusTone: Color {
        switch renderState.inputHeaderState.statusLevel {
        case .normal:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private struct IPadSelectedFileReorderDropDelegate: DropDelegate {
    let targetURL: URL
    let availableURLPaths: Set<String>
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
        guard availableURLPaths.contains(draggedURL.path) else { return }
        guard availableURLPaths.contains(targetURL.path) else { return }

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
#endif
