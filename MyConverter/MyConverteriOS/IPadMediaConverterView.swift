#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IPadMediaConverterView: View {
    let kind: ContentViewModel.MediaKind
    @ObservedObject var viewModel: ContentViewModel
    @State private var isDropTargeted = false

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
                        .fill(.white.opacity(0.08))
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(width: 140, height: 140)

                VStack(spacing: 8) {
                    Text("Drop Files Here")
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    Text("Drop files here or tap anywhere in this area to browse.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 430)
        }
        .buttonStyle(.plain)
        .padding(28)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(isDropTargeted ? kind.liquidGlassTint.opacity(0.45) : .white.opacity(0.10), lineWidth: isDropTargeted ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers, for: kind)
        }
    }

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Files")
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusTone)
                            .frame(width: 10, height: 10)
                        Text(renderState.inputHeaderState.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if renderState.screenState.isConverting {
                    Text(renderState.inputHeaderState.progressText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Drop more files here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVStack(spacing: 10) {
                ForEach(renderState.selectedFileListState.selectedURLs, id: \.self) { url in
                    IPadFileRow(
                        kind: kind,
                        url: url,
                        selectedFileListState: renderState.selectedFileListState,
                        thumbnailProvider: viewModel.services.thumbnailProvider
                    )
                }
            }
        }
        .padding(18)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(isDropTargeted ? kind.liquidGlassTint.opacity(0.45) : .white.opacity(0.10), lineWidth: isDropTargeted ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
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
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Import files to unlock compatible conversion settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Conversion Settings")
                .font(.system(size: 20, weight: .bold, design: .rounded))

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
        .padding(18)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
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

                Button(renderState.screenState.primaryActionTitle) {
                    if renderState.screenState.isConverting {
                        viewModel.cancelConversion(for: kind)
                    } else {
                        viewModel.startConversion(for: kind)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(kind.liquidGlassTint)
                .disabled(!renderState.screenState.isConverting && !renderState.screenState.canConvert)
            }
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.05),
                        kind.liquidGlassTint.opacity(0.05),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
#endif
