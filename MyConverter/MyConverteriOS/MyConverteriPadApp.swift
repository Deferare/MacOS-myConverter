#if os(iOS)
import SwiftUI

@main
struct MyConverteriPadApp: App {
    var body: some Scene {
        WindowGroup {
            IOSRootView()
        }
    }
}
#endif
