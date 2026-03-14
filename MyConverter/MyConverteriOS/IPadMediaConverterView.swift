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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isDropTargeted = false
    @State private var draggedSelectedFileURL: URL?

    private var renderState: ContentViewModel.ConverterRenderState {
        kind.converterRenderState(in: viewModel)
    }

    private var toolbarUtilityTint: Color {
        Color(uiColor: .label)
    }

    private var importSources: [ContentViewModel.ImportSource] {
        kind.availableImportSources
    }

    private var shouldShowImportSourceMenu: Bool {
        importSources.count > 1
    }

    private var settingMetrics: ConverterSettingMetrics {
        if horizontalSizeClass == .compact {
            return .phone
        }

        return .compact
    }

    var body: some View {
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
        .navigationTitle(kind.converterTitle)
        .toolbar {
            converterToolbar
        }
        .tint(kind.liquidGlassTint)
    }

    private var emptyInputSection: some View {
        VStack(spacing: 18) {
            importTriggerControl

            VStack(spacing: 8) {
                Text(isDropTargeted ? "Drop to Import" : "Drop Files Here")
                    .font(.system(size: 23, weight: .bold, design: .rounded))

                Text(
                    isDropTargeted
                        ? "Release to add the files to this queue."
                        : "Drop files here or tap the button above to browse."
                )
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 430)
        .padding(Metrics.panelPadding)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .stroke(isDropTargeted ? kind.liquidGlassTint.opacity(0.45) : .white.opacity(0.10), lineWidth: isDropTargeted ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            kind.handleDrop(providers: providers, in: viewModel)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isDropTargeted)
    }

    private var importTriggerControl: some View {
        importSourceTrigger {
            importTriggerCircle
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var importSourceMenuContent: some View {
        ForEach(importSources) { source in
            Button(source.buttonTitle) {
                kind.startImport(from: source, in: viewModel)
            }
        }
    }

    @ViewBuilder
    private func importSourceTrigger<Label: View>(
        @ViewBuilder label: () -> Label
    ) -> some View {
        if shouldShowImportSourceMenu {
            Menu {
                importSourceMenuContent
            } label: {
                label()
            }
        } else {
            Button {
                if let source = kind.defaultImportSource {
                    kind.startImport(from: source, in: viewModel)
                }
            } label: {
                label()
            }
        }
    }

    private var importTriggerCircle: some View {
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
        .contentShape(Circle())
    }

    private var filesSection: some View {
        IPadFileSelectionList(
            kind: kind,
            state: renderState.selectedFileListState,
            inputHeaderState: renderState.inputHeaderState,
            isDropTargeted: isDropTargeted,
            draggedSelectedFileURL: $draggedSelectedFileURL,
            thumbnailProvider: viewModel.services.thumbnailProvider,
            onReorder: { draggedURL, targetURL in
                kind.moveSelectedSource(from: draggedURL, to: targetURL, in: viewModel)
            }
        )
        .padding(Metrics.panelPadding)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous)
                .stroke(isDropTargeted ? kind.liquidGlassTint.opacity(0.45) : .white.opacity(0.10), lineWidth: isDropTargeted ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelCornerRadius, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            kind.handleDrop(providers: providers, in: viewModel)
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
        .converterSettingMetrics(settingMetrics)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Metrics.settingsSectionSpacing) {
            Text("Conversion Settings")
                .font(Metrics.sectionTitleFont)

            VStack(spacing: 0) {
                MediaSettingsFormContent(
                    kind: kind,
                    isConverting: renderState.screenState.isConverting,
                    viewModel: viewModel
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
        .converterSettingMetrics(settingMetrics)
    }

    @ToolbarContentBuilder
    private var converterToolbar: some ToolbarContent {
        if renderState.screenState.selectedFileCount > 0 {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !renderState.screenState.isConverting {
                    Button {
                        kind.clearSelectedSource(in: viewModel)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(toolbarUtilityTint)
                    }
                    .disabled(renderState.selectedFileListState.selectedURLs.isEmpty)

                    importSourceTrigger {
                        Image(systemName: "plus")
                            .foregroundStyle(toolbarUtilityTint)
                    }
                }

                Button {
                    if renderState.screenState.isConverting {
                        kind.cancelConversion(in: viewModel)
                    } else {
                        kind.startConversion(in: viewModel)
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
}
#endif
