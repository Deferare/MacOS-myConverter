#if os(iOS)
import SwiftUI

struct IPadImportSourceControl<Label: View>: View {
    let sources: [ContentViewModel.ImportSource]
    let defaultSource: ContentViewModel.ImportSource?
    let startImport: (ContentViewModel.ImportSource) -> Void
    let label: Label

    init(
        sources: [ContentViewModel.ImportSource],
        defaultSource: ContentViewModel.ImportSource?,
        startImport: @escaping (ContentViewModel.ImportSource) -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.sources = sources
        self.defaultSource = defaultSource
        self.startImport = startImport
        self.label = label()
    }

    var body: some View {
        Group {
            if sources.count > 1 {
                Menu {
                    ForEach(sources) { source in
                        Button(source.buttonTitle) {
                            startImport(source)
                        }
                    }
                } label: {
                    label
                }
            } else {
                Button {
                    if let defaultSource {
                        startImport(defaultSource)
                    }
                } label: {
                    label
                }
            }
        }
    }
}

struct IPadImportTriggerCircle: View {
    let tint: Color
    let isDropTargeted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(isDropTargeted ? 0.20 : 0.14))
                .overlay(
                    Circle()
                        .stroke(
                            isDropTargeted ? tint.opacity(0.34) : .white.opacity(0.10),
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
}
#endif
