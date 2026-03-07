import SwiftUI

struct SelectedFileCardView: View {
    let url: URL
    let order: Int
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .padding(10)
                    .glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                Text("\(order)")
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Text(url.lastPathComponent)
                .font(.body.weight(.semibold))
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(url.pathExtension.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular.interactive(false), in: Capsule())
                Spacer()
            }
        }
        .padding(12)
        .frame(width: 140, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}
