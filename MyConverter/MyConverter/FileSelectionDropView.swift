import AppKit
import SwiftUI

struct ConverterInputAreaBackground: View {
    let isDropTargeted: Bool
    let usesDashedBorder: Bool

    private let cornerRadius: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        isDropTargeted ? Color.accentColor.opacity(0.10) : .white.opacity(0.05),
                        isDropTargeted ? Color.accentColor.opacity(0.03) : .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1.5)
                }
            }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                }
            }
    }
}

struct DropFileView: View {
    let isDropTargeted: Bool
    let placeholder: String
    let fileDropAreaHeight: CGFloat
    let action: () -> Void

    private var decorativeGlass: Glass {
        Glass.regular.interactive(false)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "plus.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.primary)
                .symbolRenderingMode(.hierarchical)
                .padding(24)
                .glassEffect(decorativeGlass, in: Circle())
                .scaleEffect(isDropTargeted ? 1.08 : 1.0)

            VStack(spacing: 10) {
                Text(isDropTargeted ? "Drop to Import" : placeholder)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(isDropTargeted ? "Release to add the files to this queue" : "Drop files here or click anywhere in this area to browse.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: fileDropAreaHeight)
        .background(
            ConverterInputAreaBackground(
                isDropTargeted: isDropTargeted,
                usesDashedBorder: true
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.03))
                .blur(radius: isDropTargeted ? 18 : 0)
                .opacity(isDropTargeted ? 1 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            action()
        }
        .onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .scaleEffect(isDropTargeted ? 1.005 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDropTargeted)
    }
}
