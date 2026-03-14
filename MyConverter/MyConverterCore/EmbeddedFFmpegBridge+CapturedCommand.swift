#if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
import Darwin
import FFmpegSupport
import Foundation

extension EmbeddedFFmpegBridge {
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
}
#endif
