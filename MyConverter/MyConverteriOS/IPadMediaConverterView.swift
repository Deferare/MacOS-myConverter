#if os(iOS)
import SwiftUI

struct IPadMediaConverterView: View {
    let kind: ContentViewModel.MediaKind
    @ObservedObject var viewModel: ContentViewModel

    private var renderState: ContentViewModel.ConverterRenderState {
        viewModel.converterRenderState(for: kind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroSection
                    actionsSection
                    fileListSection
                    settingsSection
                }
                .padding(20)
                .frame(maxWidth: 960)
                .frame(maxWidth: .infinity)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle(kind.converterTitle)
        }
    }

    private var heroSection: some View {
        AboutPanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(kind.converterTitle, systemImage: kind.inputSystemImage)
                    .font(.title2.weight(.bold))

                Text(renderState.inputHeaderState.statusMessage)
                    .font(.headline)

                HStack(spacing: 14) {
                    statusPill(
                        title: renderState.screenState.selectedFormatLabel,
                        systemImage: "wand.and.stars"
                    )
                    statusPill(
                        title: renderState.screenState.destinationHint,
                        systemImage: "folder"
                    )
                }

                if renderState.screenState.isConverting {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: viewModel.displayedProgress(for: kind))
                            .tint(kind.liquidGlassTint)
                        Text(renderState.inputHeaderState.progressText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        AboutPanelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Actions")
                        .font(.headline)
                    Spacer()
                }

                HStack(spacing: 12) {
                    Button("Add Files", systemImage: "plus") {
                        viewModel.requestFileImport()
                    }
                    .buttonStyle(.bordered)
                    .disabled(renderState.screenState.isConverting)

                    Button("Choose Folder", systemImage: "folder.badge.plus") {
                        Task {
                            await viewModel.chooseOutputDirectory(for: kind)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(renderState.screenState.isConverting)

                    Button("Clear", systemImage: "trash") {
                        viewModel.clearSelectedSource(for: kind)
                    }
                    .buttonStyle(.bordered)
                    .disabled(renderState.selectedFileListState.selectedURLs.isEmpty || renderState.screenState.isConverting)

                    Spacer()

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
    }

    private var fileListSection: some View {
        AboutPanelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Selected Files")
                        .font(.headline)
                    Spacer()
                    Text("\(renderState.selectedFileListState.selectedURLs.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if renderState.selectedFileListState.selectedURLs.isEmpty {
                    ContentUnavailableView(
                        "No Files Selected",
                        systemImage: "tray",
                        description: Text("Add files from the Files app to start configuring this conversion.")
                    )
                } else {
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
            }
        }
    }

    @ViewBuilder
    private var settingsSection: some View {
        if renderState.screenState.showsSettings {
            AboutPanelCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Conversion Settings")
                        .font(.headline)

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
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                kind.liquidGlassTint.opacity(0.30),
                Color(.systemBackground),
                kind.liquidGlassTint.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func statusPill(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.08), in: Capsule())
    }
}
#endif
