#if os(macOS)
import AppKit
import SwiftUI

struct UnifiedFileRowCompletedActionsView: View {
    let url: URL
    let spacing: CGFloat
    let buttonHeight: CGFloat
    let labelColor: Color
    let fillColor: Color
    let borderColor: Color

    var body: some View {
        HStack(spacing: spacing) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Label("Show in Finder", systemImage: "folder")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(labelColor)
                    .frame(width: 38, height: buttonHeight)
                    .background(actionButtonBackground)
            }
            .buttonStyle(HoverScaleButtonStyle())
            .help("Show in Finder")

            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Text("Open")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(labelColor)
                    .padding(.horizontal, 18)
                    .frame(height: buttonHeight)
                    .background(actionButtonBackground)
            }
            .buttonStyle(HoverScaleButtonStyle())
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var actionButtonBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

struct UnifiedFileRowStatusPlaceholderView: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(Glass.regular.tint(color).interactive(false), in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }
}

struct HoverScaleButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : (isHovered ? 1.04 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation {
                    isHovered = hovering
                }
            }
    }
}
#endif
