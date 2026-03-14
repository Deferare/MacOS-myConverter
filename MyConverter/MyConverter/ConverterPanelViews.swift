#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ConverterPanelCard<Content: View>: View {
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
#endif
