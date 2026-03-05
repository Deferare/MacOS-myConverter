import SwiftUI

struct DropFileView: View {
    let isDropTargeted: Bool
    let placeholder: String
    let fileDropAreaHeight: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.15) : Color.accentColor.opacity(0.05))
                        .frame(width: 88, height: 88)
                        .blur(radius: isDropTargeted ? 10 : 0)
                        .scaleEffect(isDropTargeted ? 1.15 : 1.0)

                    Circle()
                        .stroke(Color.accentColor.opacity(isDropTargeted ? 0.3 : 0.1), lineWidth: 1)
                        .frame(width: 104, height: 104)
                        .scaleEffect(isDropTargeted ? 1.05 : 1.0)

                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.6))
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(isDropTargeted ? 1.1 : 1.0)
                }

                VStack(spacing: 8) {
                    Text(isDropTargeted ? "Drop to Import" : placeholder)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .primary)

                    Text(isDropTargeted ? "Release to start conversion setup" : "or click to browse local files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: fileDropAreaHeight)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.03) : Color.primary.opacity(0.01))

                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2),
                            style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: isDropTargeted ? [] : [4, 4])
                        )
                }
            )
            .contentShape(Rectangle())
            .scaleEffect(isDropTargeted ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isDropTargeted)
    }
}
