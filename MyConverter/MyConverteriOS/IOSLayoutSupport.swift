#if os(iOS)
import SwiftUI

struct IOSLayoutReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let content: (IOSLayoutClass) -> Content

    init(
        @ViewBuilder content: @escaping (IOSLayoutClass) -> Content
    ) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = IOSLayoutClass.resolve(
                hasCompactWidth: horizontalSizeClass == .compact,
                availableWidth: proxy.size.width
            )

            content(layout)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
#endif
