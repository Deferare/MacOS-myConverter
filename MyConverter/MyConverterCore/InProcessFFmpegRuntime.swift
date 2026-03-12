import Foundation
#if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
import Darwin
import FFmpegSupport
#endif

enum EmbeddedFFmpegBridge {
    nonisolated static var isConfigured: Bool {
        #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
        true
        #else
        false
        #endif
    }

    nonisolated private static let executionLock = NSLock()

    nonisolated static func runCommand(
        arguments: [String],
        outputLineHandler: (@Sendable (String) -> Void)?
    ) async throws -> FFmpegCommandResult {
        #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
        return try await Task.detached(priority: .userInitiated) {
            try runCapturedCommand(
                arguments: arguments,
                outputLineHandler: outputLineHandler
            )
        }.value
        #else
        throw FFmpegRuntimeError.unavailable(
            "The in-process FFmpeg bridge is not configured for this build."
        )
        #endif
    }

    nonisolated static func runCommandSync(arguments: [String]) -> FFmpegCommandResult {
        #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
        do {
            return try runCapturedCommand(arguments: arguments, outputLineHandler: nil)
        } catch {
            return FFmpegCommandResult(
                terminationStatus: -1,
                output: error.localizedDescription
            )
        }
        #else
        FFmpegCommandResult(
            terminationStatus: -1,
            output: "The in-process FFmpeg bridge is not configured for this build."
        )
        #endif
    }

    #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
    nonisolated private static func runCapturedCommand(
        arguments: [String],
        outputLineHandler: (@Sendable (String) -> Void)?
    ) throws -> FFmpegCommandResult {
        executionLock.lock()
        defer { executionLock.unlock() }

        let commandArguments = arguments.first == "ffmpeg"
            ? arguments
            : ["ffmpeg"] + arguments

        var pipeDescriptors = [Int32](repeating: 0, count: 2)
        guard pipe(&pipeDescriptors) == 0 else {
            throw FFmpegRuntimeError.unavailable("Failed to create FFmpeg output pipe.")
        }

        let readDescriptor = pipeDescriptors[0]
        let writeDescriptor = pipeDescriptors[1]
        let savedStdout = dup(STDOUT_FILENO)
        let savedStderr = dup(STDERR_FILENO)
        guard savedStdout >= 0, savedStderr >= 0 else {
            close(readDescriptor)
            close(writeDescriptor)
            throw FFmpegRuntimeError.unavailable("Failed to duplicate output descriptors.")
        }

        var accumulated = Data()
        var lineBuffer = Data()
        let readerGroup = DispatchGroup()
        readerGroup.enter()

        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                close(readDescriptor)
                readerGroup.leave()
            }

            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let bytesRead = read(readDescriptor, &buffer, buffer.count)
                if bytesRead > 0 {
                    let data = Data(buffer.prefix(Int(bytesRead)))
                    accumulated.append(data)
                    lineBuffer.append(data)

                    let lines = consumeCompleteLines(from: &lineBuffer)
                    guard let outputLineHandler else { continue }
                    for line in lines {
                        outputLineHandler(line)
                    }
                } else {
                    break
                }
            }

            if let outputLineHandler,
               !lineBuffer.isEmpty,
               let trailingLine = String(data: lineBuffer, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !trailingLine.isEmpty {
                outputLineHandler(trailingLine)
            }
        }

        fflush(nil)
        dup2(writeDescriptor, STDOUT_FILENO)
        dup2(writeDescriptor, STDERR_FILENO)

        let status = ffmpeg(commandArguments)

        fflush(nil)
        dup2(savedStdout, STDOUT_FILENO)
        dup2(savedStderr, STDERR_FILENO)
        close(savedStdout)
        close(savedStderr)
        close(writeDescriptor)
        readerGroup.wait()

        return FFmpegCommandResult(
            terminationStatus: Int32(status),
            output: String(decoding: accumulated, as: UTF8.self)
        )
    }

    nonisolated private static func consumeCompleteLines(from buffer: inout Data) -> [String] {
        var lines: [String] = []
        let newline = Data([0x0A])

        while let range = buffer.range(of: newline) {
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            let text = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty {
                lines.append(text)
            }
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
        }

        return lines
    }
    #endif
}

struct InProcessFFmpegRuntime: FFmpegRuntime {
    nonisolated init() {}

    nonisolated static func makeIfAvailable() -> (any FFmpegRuntime)? {
        guard EmbeddedFFmpegBridge.isConfigured else {
            return nil
        }
        return InProcessFFmpegRuntime()
    }

    var cacheIdentity: String {
        "inprocess:ffmpeg"
    }

    var displayName: String {
        "embedded-ffmpeg"
    }

    func runCommand(
        arguments: [String],
        outputLineHandler: (@Sendable (String) -> Void)?
    ) async throws -> FFmpegCommandResult {
        try await EmbeddedFFmpegBridge.runCommand(
            arguments: arguments,
            outputLineHandler: outputLineHandler
        )
    }

    func runCommandSync(arguments: [String]) -> FFmpegCommandResult {
        EmbeddedFFmpegBridge.runCommandSync(arguments: arguments)
    }
}
