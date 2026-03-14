#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

struct IPadMediaConverterView: View {
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
        .background(IPadMediaConverterBackground(tint: kind.liquidGlassTint).ignoresSafeArea())
        .navigationTitle(kind.converterTitle)
        .toolbar {
            IPadMediaConverterToolbarContent(
                screenState: renderState.screenState,
                selectedURLs: renderState.selectedFileListState.selectedURLs,
                utilityTint: toolbarUtilityTint,
                actionTint: kind.liquidGlassTint,
                onClear: {
                    kind.clearSelectedSource(in: viewModel)
                },
                onPrimaryAction: {
                    if renderState.screenState.isConverting {
                        kind.cancelConversion(in: viewModel)
                    } else {
                        kind.startConversion(in: viewModel)
                    }
                },
                importControl: {
                    importSourceControl {
                        Image(systemName: "plus")
                            .foregroundStyle(toolbarUtilityTint)
                    }
                }
            )
        }
        .tint(kind.liquidGlassTint)
    }

    private var emptyInputSection: some View {
        VStack(spacing: 18) {
            importSourceControl {
                IPadImportTriggerCircle(
                    tint: kind.liquidGlassTint,
                    isDropTargeted: isDropTargeted
                )
            }
            .buttonStyle(.plain)

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
        .padding(IPadMediaConverterStyle.panelPadding)
        .background(IPadMediaConverterPanelBackground(tint: kind.liquidGlassTint))
        .overlay(
            RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous)
                .stroke(isDropTargeted ? kind.liquidGlassTint.opacity(0.45) : .white.opacity(0.10), lineWidth: isDropTargeted ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            kind.handleDrop(providers: providers, in: viewModel)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isDropTargeted)
    }

    private func importSourceControl<Label: View>(
        @ViewBuilder label: () -> Label
    ) -> some View {
        IPadImportSourceControl(
            sources: kind.availableImportSources,
            defaultSource: kind.defaultImportSource,
            startImport: { source in
                kind.startImport(from: source, in: viewModel)
            },
            label: label
        )
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
        .padding(IPadMediaConverterStyle.panelPadding)
        .background(IPadMediaConverterPanelBackground(tint: kind.liquidGlassTint))
        .overlay(
            RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous)
                .stroke(isDropTargeted ? kind.liquidGlassTint.opacity(0.45) : .white.opacity(0.10), lineWidth: isDropTargeted ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous))
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            kind.handleDrop(providers: providers, in: viewModel)
        }
    }

    private var emptySettingsSection: some View {
        IPadEmptySettingsPanel(settingMetrics: settingMetrics)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: IPadMediaConverterStyle.settingsSectionSpacing) {
            Text("Conversion Settings")
                .font(IPadMediaConverterStyle.sectionTitleFont)

            VStack(spacing: 0) {
                MediaSettingsFormContent(
                    kind: kind,
                    isConverting: renderState.screenState.isConverting,
                    viewModel: viewModel
                )
            }
        }
        .padding(IPadMediaConverterStyle.panelPadding)
        .background(IPadMediaConverterPanelBackground(tint: kind.liquidGlassTint))
        .overlay(
            RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: IPadMediaConverterStyle.panelCornerRadius, style: .continuous))
        .converterSettingMetrics(settingMetrics)
    }
}
#endif
