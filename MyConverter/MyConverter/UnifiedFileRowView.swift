import AppKit
import SwiftUI

struct UnifiedFileRowView: View {
    let sourceURL: URL
    let outputURL: URL?
    let order: Int
    let systemImage: String
    let isConverting: Bool
    let isCurrentlyConverting: Bool

    var body: some View {
        HStack(spacing: 0) {
            sourceSection
            arrowIndicator
            outputSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(rowBackground)
    }

    // MARK: - Source Section

    private var sourceSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(order)")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.05)))

                    Text(sourceURL.lastPathComponent)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text(sourceURL.pathExtension.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.04)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Arrow Indicator

    private var arrowIndicator: some View {
        ZStack {
            if isCurrentlyConverting {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(arrowColor)
            }
        }
        .frame(width: 36)
    }

    private var arrowColor: Color {
        if outputURL != nil {
            return .green
        } else if isConverting {
            return .secondary.opacity(0.3)
        } else {
            return .secondary.opacity(0.4)
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        Group {
            if let outputURL {
                completedOutputView(outputURL)
            } else if isCurrentlyConverting {
                convertingPlaceholderView
            } else {
                pendingPlaceholderView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func completedOutputView(_ url: URL) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(url.pathExtension.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.green.opacity(0.1)))
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help("Show in Finder")

                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text("Open")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var convertingPlaceholderView: some View {
        HStack(spacing: 8) {
            Text("Converting…")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var pendingPlaceholderView: some View {
        Text("Pending")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tertiary)
    }

    // MARK: - Background

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(rowFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(rowBorderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
    }

    private var rowFillColor: Color {
        if isCurrentlyConverting {
            return Color.accentColor.opacity(0.03)
        } else if outputURL != nil {
            return Color.green.opacity(0.02)
        } else {
            return Color.primary.opacity(0.015)
        }
    }

    private var rowBorderColor: Color {
        if isCurrentlyConverting {
            return Color.accentColor.opacity(0.12)
        } else if outputURL != nil {
            return Color.green.opacity(0.1)
        } else {
            return Color.primary.opacity(0.06)
        }
    }
}
