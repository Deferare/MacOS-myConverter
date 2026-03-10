import Foundation
#if DEBUG
import os.signpost
#endif

enum PerformanceSignpost {
#if DEBUG
    nonisolated private static let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "MyConverter",
        category: "Performance"
    )

    typealias IntervalToken = OSSignpostID

    nonisolated static func event(_ name: StaticString, message: String = "") {
        if message.isEmpty {
            os_signpost(.event, log: log, name: name)
        } else {
            os_signpost(.event, log: log, name: name, "%{public}s", message)
        }
    }

    nonisolated static func begin(_ name: StaticString, message: String = "") -> IntervalToken {
        let token = OSSignpostID(log: log)
        if message.isEmpty {
            os_signpost(.begin, log: log, name: name, signpostID: token)
        } else {
            os_signpost(.begin, log: log, name: name, signpostID: token, "%{public}s", message)
        }
        return token
    }

    nonisolated static func end(_ name: StaticString, token: IntervalToken, message: String = "") {
        if message.isEmpty {
            os_signpost(.end, log: log, name: name, signpostID: token)
        } else {
            os_signpost(.end, log: log, name: name, signpostID: token, "%{public}s", message)
        }
    }
#else
    struct IntervalToken {}

    nonisolated static func event(_: StaticString, message _: String = "") {}

    nonisolated static func begin(_: StaticString, message _: String = "") -> IntervalToken {
        IntervalToken()
    }

    nonisolated static func end(_: StaticString, token _: IntervalToken, message _: String = "") {}
#endif
}
