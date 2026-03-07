import AppKit
import SwiftUI

struct OutputFilesSection: View {
    let urls: [URL]

    var body: some View {
        Section("Output Files") {
            if urls.isEmpty {
                Text("Converted files will appear here")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(urls.enumerated()), id: \.element.path) { index, url in
                        OutputFileCardView(
                            url: url,
                            order: index + 1
                        )
                    }
                }
                .padding(.vertical, 4)
                .transition(.identity)
            }
        }
    }
}

struct OutputFileCardView: View {
    let url: URL
    let order: Int

    private var statusGlass: Glass {
        Glass.regular.tint(.green).interactive(false)
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark")
                .font(.callout.weight(.bold))
                .foregroundStyle(.green)
                .padding(12)
                .glassEffect(statusGlass, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(order)")
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.interactive(false), in: Capsule())

                    Text(url.lastPathComponent)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text(url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .tint(.secondary)

                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text("Open")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}
