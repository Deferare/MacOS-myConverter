#if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
import Darwin
import FFmpegSupport
import Foundation

extension EmbeddedFFmpegBridge {
    typealias CVoidFunction = @convention(c) () -> Void

    nonisolated static func resolveMutableInt32Symbol(_ name: String) -> UnsafeMutablePointer<Int32>? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            return nil
        }
        return symbol.assumingMemoryBound(to: Int32.self)
    }

    nonisolated static func resolveVoidFunction(_ name: String) -> CVoidFunction? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: CVoidFunction.self)
    }
}
#endif
