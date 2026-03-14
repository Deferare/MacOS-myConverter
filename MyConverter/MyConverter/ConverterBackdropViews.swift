#if os(macOS)
import AppKit
import SwiftUI

struct LiquidGlassBackdrop: View {
    let tint: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .underPageBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 96)
                .offset(x: 240, y: -220)

            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -260, y: 260)

            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 480, height: 220)
                .blur(radius: 120)
                .offset(x: -120, y: -260)
        }
    }
}

struct MediaKindBackdrop: View, Equatable {
    let kind: ContentViewModel.MediaKind

    static func == (lhs: MediaKindBackdrop, rhs: MediaKindBackdrop) -> Bool {
        lhs.kind == rhs.kind
    }

    var body: some View {
        LiquidGlassBackdrop(tint: kind.liquidGlassTint)
    }
}
#endif
