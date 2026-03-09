import Foundation
#if DEBUG
import os.signpost
#endif

enum PerformanceSignpost {
#if DEBUG
    private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "MyConverter",
        category: "Performance"
    )

    static func event(_ name: StaticString, message: String = "") {
        if message.isEmpty {
            os_signpost(.event, log: log, name: name)
        } else {
            os_signpost(.event, log: log, name: name, "%{public}s", message)
        }
    }
#else
    static func event(_: StaticString, message _: String = "") {}
#endif
}
