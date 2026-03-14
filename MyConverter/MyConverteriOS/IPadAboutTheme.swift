#if os(iOS)
import SwiftUI

enum IPadAboutThemeMetrics {
    static let horizontalPadding: CGFloat = 24
    static let verticalPadding: CGFloat = 20
    static let panelCornerRadius: CGFloat = 28
    static let heroIconSize: CGFloat = 132
    static let heroSymbolSize: CGFloat = 44
}

struct IPadAboutBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.blue.opacity(0.20))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 240, y: -220)

            Circle()
                .fill(Color.cyan.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -220, y: 260)

            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 420, height: 220)
                .blur(radius: 120)
                .offset(x: -100, y: -250)
        }
    }
}

struct IPadAboutPanelCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: IPadAboutThemeMetrics.panelCornerRadius, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: IPadAboutThemeMetrics.panelCornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }
}
#endif
