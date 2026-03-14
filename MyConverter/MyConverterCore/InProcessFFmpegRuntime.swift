import Foundation
#if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
import Darwin
import FFmpegSupport
#endif

enum EmbeddedFFmpegBridge {
    private struct BridgeExecutionState: Sendable {
        var executionThreadRawValue: UInt?
        var inputWriteDescriptor: Int32 = -1
    }

    nonisolated static var isConfigured: Bool {
        #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
        true
        #else
        false
        #endif
    }

    nonisolated private static let executionLock = NSLock()
    nonisolated private static let stateQueue = DispatchQueue(label: "myconverter.ffmpeg.bridge.state")
    nonisolated(unsafe) private static var executionState = BridgeExecutionState()

    nonisolated private static func currentExecutionState() -> BridgeExecutionState {
        stateQueue.sync { executionState }
    }

    nonisolated private static func updateExecutionState(
        _ update: (inout BridgeExecutionState) -> Void
    ) {
        stateQueue.sync {
            update(&executionState)
        }
    }

    nonisolated private static func executionThread(
        from rawValue: UInt?
    ) -> pthread_t? {
        rawValue.flatMap { pthread_t(bitPattern: $0) }
    }

    nonisolated static func runCommand(
        arguments: [String],
        outputLineHandler: (@Sendable (String) -> Void)?
    ) async throws -> FFmpegCommandResult {
        #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
        let task = Task.detached(priority: .userInitiated) {
            try runCapturedCommand(
                arguments: arguments,
                outputLineHandler: outputLineHandler
            )
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            cancelCurrentCommand()
            task.cancel()
        }
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

    nonisolated static func cancelCurrentCommand() {
        #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
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
        #endif
    }

    #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
    private typealias CVoidFunction = @convention(c) () -> Void

    nonisolated private static func resolveMutableInt32Symbol(_ name: String) -> UnsafeMutablePointer<Int32>? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            return nil
        }
        return symbol.assumingMemoryBound(to: Int32.self)
    }

    nonisolated private static func resolveVoidFunction(_ name: String) -> CVoidFunction? {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: CVoidFunction.self)
    }

    nonisolated private static func runCapturedCommand(
        arguments: [String],
        outputLineHandler: (@Sendable (String) -> Void)?
    ) throws -> FFmpegCommandResult {
        executionLock.lock()
        let currentThreadRawValue = UInt(bitPattern: pthread_self())
        updateExecutionState { $0.executionThreadRawValue = currentThreadRawValue }
        defer {
            updateExecutionState { $0.executionThreadRawValue = nil }
            executionLock.unlock()
        }

        let commandArguments = arguments.first == "ffmpeg"
            ? arguments
            : ["ffmpeg"] + arguments

        let stdinInteractionPointer = resolveMutableInt32Symbol("stdin_interaction")
        let previousStdinInteraction = stdinInteractionPointer?.pointee
        stdinInteractionPointer?.pointee = 1
        let termInit = resolveVoidFunction("term_init")
        let termExit = resolveVoidFunction("term_exit")
        termInit?()

        var inputPipeDescriptors = [Int32](repeating: 0, count: 2)
        guard pipe(&inputPipeDescriptors) == 0 else {
            if let previousStdinInteraction {
                stdinInteractionPointer?.pointee = previousStdinInteraction
            }
            termExit?()
            throw FFmpegRuntimeError.unavailable("Failed to create FFmpeg input pipe.")
        }

        let inputReadDescriptor = inputPipeDescriptors[0]
        let inputWriteDescriptor = inputPipeDescriptors[1]

        var pipeDescriptors = [Int32](repeating: 0, count: 2)
        guard pipe(&pipeDescriptors) == 0 else {
            if let previousStdinInteraction {
                stdinInteractionPointer?.pointee = previousStdinInteraction
            }
            termExit?()
            close(inputReadDescriptor)
            close(inputWriteDescriptor)
            throw FFmpegRuntimeError.unavailable("Failed to create FFmpeg output pipe.")
        }

        let readDescriptor = pipeDescriptors[0]
        let writeDescriptor = pipeDescriptors[1]
        let savedStdin = dup(STDIN_FILENO)
        let savedStdout = dup(STDOUT_FILENO)
        let savedStderr = dup(STDERR_FILENO)
        guard savedStdin >= 0, savedStdout >= 0, savedStderr >= 0 else {
            if let previousStdinInteraction {
                stdinInteractionPointer?.pointee = previousStdinInteraction
            }
            termExit?()
            close(inputReadDescriptor)
            close(inputWriteDescriptor)
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
        dup2(inputReadDescriptor, STDIN_FILENO)
        dup2(writeDescriptor, STDOUT_FILENO)
        dup2(writeDescriptor, STDERR_FILENO)
        close(inputReadDescriptor)
        updateExecutionState { $0.inputWriteDescriptor = inputWriteDescriptor }

        let status = ffmpeg(commandArguments)

        fflush(nil)
        updateExecutionState { $0.inputWriteDescriptor = -1 }
        dup2(savedStdin, STDIN_FILENO)
        dup2(savedStdout, STDOUT_FILENO)
        dup2(savedStderr, STDERR_FILENO)
        close(savedStdin)
        close(savedStdout)
        close(savedStderr)
        close(inputWriteDescriptor)
        close(writeDescriptor)
        readerGroup.wait()
        termExit?()
        if let previousStdinInteraction {
            stdinInteractionPointer?.pointee = previousStdinInteraction
        }

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
