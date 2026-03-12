#if os(iOS)
import SwiftUI

struct IPadMediaConverterView: View {
    let kind: ContentViewModel.MediaKind
    @ObservedObject var viewModel: ContentViewModel

    private var renderState: ContentViewModel.ConverterRenderState {
        viewModel.converterRenderState(for: kind)
    }

    private var completedOutputURLs: [URL] {
        renderState.selectedFileListState.outputURLsBySourceID.values
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    mainContent
                }
                .padding(20)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle(kind.converterTitle)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            kind.liquidGlassTint.opacity(0.36),
                            kind.liquidGlassTint.opacity(0.14),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.14))
                        Image(systemName: kind.inputSystemImage)
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(kind.converterTitle)
                            .font(.system(size: 31, weight: .black, design: .rounded))

                        Text(heroSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        statusPill(
                            title: renderState.inputHeaderState.statusMessage,
                            systemImage: statusSystemImage,
                            tone: statusTone
                        )
                    }

                    Spacer()
                }

                HStack(spacing: 14) {
                    metricCard(
                        title: "Files",
                        value: "\(renderState.screenState.selectedFileCount)",
                        systemImage: "square.stack.3d.up"
                    )
                    metricCard(
                        title: "Format",
                        value: renderState.screenState.selectedFormatLabel,
                        systemImage: "wand.and.stars"
                    )
                    metricCard(
                        title: "Saved",
                        value: "\(renderState.screenState.convertedCount)",
                        systemImage: "checkmark.circle"
                    )
                }

                if renderState.screenState.isConverting {
                    VStack(alignment: .leading, spacing: 10) {
                        ProgressView(value: viewModel.displayedProgress(for: kind))
                            .tint(.white)
                        Text(renderState.inputHeaderState.progressText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                leftColumn
                    .frame(maxWidth: .infinity, alignment: .top)
                rightColumn
                    .frame(width: 390, alignment: .top)
            }

            VStack(spacing: 18) {
                leftColumn
                rightColumn
            }
        }
    }

    private var leftColumn: some View {
        VStack(spacing: 18) {
            fileListSection
            if renderState.screenState.showsResults {
                resultSection
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: 18) {
            actionsSection
            outputSection
            settingsSection
        }
    }

    private var actionsSection: some View {
        AboutPanelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Controls")
                        .font(.headline)
                    Spacer()
                    Text(renderState.screenState.isConverting ? "Live" : "Ready")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusTone)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusTone.opacity(0.12), in: Capsule())
                }

                Text(primaryActionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Add Files", systemImage: "plus") {
                            viewModel.requestFileImport()
                        }
                        .buttonStyle(.bordered)
                        .disabled(renderState.screenState.isConverting)

                        Button(
                            viewModel.hasSelectedOutputDirectory(for: kind) ? "Change Folder" : "Choose Folder",
                            systemImage: "folder.badge.plus"
                        ) {
                            Task {
                                await viewModel.chooseOutputDirectory(for: kind)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(renderState.screenState.isConverting)
                    }

                    Button("Clear Selection", systemImage: "trash") {
                        viewModel.clearSelectedSource(for: kind)
                    }
                    .buttonStyle(.bordered)
                    .disabled(renderState.selectedFileListState.selectedURLs.isEmpty || renderState.screenState.isConverting)

                    Button(renderState.screenState.primaryActionTitle) {
                        if renderState.screenState.isConverting {
                            viewModel.cancelConversion(for: kind)
                        } else {
                            viewModel.startConversion(for: kind)
                        }
                    }
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(kind.liquidGlassTint)
                    .disabled(!renderState.screenState.isConverting && !renderState.screenState.canConvert)
                }
            }
        }
    }

    private var outputSection: some View {
        AboutPanelCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Destination")
                    .font(.headline)

                Text(renderState.screenState.destinationHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let outputDirectory = viewModel.selectedOutputDirectoryURL(for: kind) {
                    Text(outputDirectory.lastPathComponent)
                        .font(.body.weight(.semibold))
                } else {
                    Text("Choose a folder before you convert.")
                        .font(.body.weight(.semibold))
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

    private var resultSection: some View {
        AboutPanelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Results")
                        .font(.headline)
                    Spacer()
                    Text("\(completedOutputURLs.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                LazyVStack(spacing: 10) {
                    ForEach(completedOutputURLs, id: \.self) { url in
                        IPadResultRow(
                            url: url,
                            kind: kind,
                            thumbnailProvider: viewModel.services.thumbnailProvider
                        )
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
        } else {
            AboutPanelCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Conversion Settings")
                        .font(.headline)
                    Text("Add a source file to unlock compatible settings for this media type.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                kind.liquidGlassTint.opacity(0.32),
                Color(.systemBackground),
                kind.liquidGlassTint.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func statusPill(title: String, systemImage: String, tone: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tone.opacity(0.12), in: Capsule())
    }

    private func metricCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    private var statusSystemImage: String {
        switch renderState.inputHeaderState.statusLevel {
        case .normal:
            return renderState.screenState.isConverting ? "gearshape.2" : "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }

    private var heroSubtitle: String {
        switch kind {
        case .video:
            return "Tune codecs, rescue tricky containers, and keep long-running conversions visible on one dashboard."
        case .image:
            return "Convert stills and animations with larger previews, quick quality checks, and cleaner export controls."
        case .audio:
            return "Extract or transcode audio with output options that stay easy to read while batches are running."
        }
    }

    private var primaryActionDescription: String {
        if renderState.screenState.canConvert {
            return renderState.screenState.isConverting
                ? "Cancel stops the active AVFoundation or FFmpeg pipeline and leaves unfinished files behind."
                : "Everything is ready. Start conversion when the destination and format look right."
        }

        return renderState.inputHeaderState.statusMessage
    }
}
#endif
