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

    nonisolated static func runCapturedCommand(
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

    nonisolated static func consumeCompleteLines(from buffer: inout Data) -> [String] {
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
}
#endif
