#if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
import Darwin
import FFmpegSupport
import Foundation

extension EmbeddedFFmpegBridge {
    struct BridgeExecutionState: Sendable {
        var executionThreadRawValue: UInt?
        var inputWriteDescriptor: Int32 = -1
    }

    nonisolated static let executionLock = NSLock()
    nonisolated static let stateQueue = DispatchQueue(label: "myconverter.ffmpeg.bridge.state")
    nonisolated(unsafe) static var executionState = BridgeExecutionState()

    nonisolated static func currentExecutionState() -> BridgeExecutionState {
        stateQueue.sync { executionState }
    }

    nonisolated static func updateExecutionState(
        _ update: (inout BridgeExecutionState) -> Void
    ) {
        stateQueue.sync {
            update(&executionState)
        }
    }

    nonisolated static func executionThread(
        from rawValue: UInt?
    ) -> pthread_t? {
        rawValue.flatMap { pthread_t(bitPattern: $0) }
    }

    nonisolated static func cancelCurrentCommand() {
        let state = currentExecutionState()
        let inputWriteDescriptor = state.inputWriteDescriptor

        if inputWriteDescriptor >= 0 {
            let bytes = Array("q\n".utf8)
            _ = bytes.withUnsafeBytes { buffer in
                write(inputWriteDescriptor, buffer.baseAddress, buffer.count)
            }
        }

        let signals: [Int32] = [SIGINT, SIGINT, SIGTERM]

        DispatchQueue.global(qos: .userInitiated).async {
            for signal in signals {
                if let thread = executionThread(from: state.executionThreadRawValue) {
                    pthread_kill(thread, signal)
                }
                kill(getpid(), signal)
                usleep(50_000)
            }
        }
    }
}
#endif
