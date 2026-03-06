import Foundation

extension ProcessCommandRunner {
    nonisolated static func runCommand(
        path: String,
        arguments: [String],
        maximumRetainedOutputBytes: Int = 262_144,
        outputLineHandler: ((String) -> Void)? = nil
    ) async throws -> (terminationStatus: Int32, output: String) {
        let cancellationController = ProcessCancellationController()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int32, String), Error>) in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                cancellationController.setProcess(process)

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe
                let outputHandle = outputPipe.fileHandleForReading
                let syncQueue = DispatchQueue(label: "myconverter.commandrunner.output")
                var accumulated = Data()
                var lineBuffer = Data()

                outputHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }

                    syncQueue.async {
                        appendRetainedOutput(
                            &accumulated,
                            chunk: data,
                            maximumRetainedOutputBytes: maximumRetainedOutputBytes
                        )
                        lineBuffer.append(data)
                        let lines = consumeCompleteLines(from: &lineBuffer)
                        guard let outputLineHandler else { return }
                        for line in lines {
                            outputLineHandler(line)
                        }
                    }
                }

                process.terminationHandler = { proc in
                    outputHandle.readabilityHandler = nil
                    let trailingData = outputHandle.readDataToEndOfFile()

                    syncQueue.async {
                        if !trailingData.isEmpty {
                            appendRetainedOutput(
                                &accumulated,
                                chunk: trailingData,
                                maximumRetainedOutputBytes: maximumRetainedOutputBytes
                            )
                            lineBuffer.append(trailingData)
                        }

                        let lines = consumeCompleteLines(from: &lineBuffer)
                        if let outputLineHandler {
                            for line in lines {
                                outputLineHandler(line)
                            }

                            if !lineBuffer.isEmpty,
                               let trailingLine = String(data: lineBuffer, encoding: .utf8)?
                                .trimmingCharacters(in: .whitespacesAndNewlines),
                               !trailingLine.isEmpty {
                                outputLineHandler(trailingLine)
                            }
                        }

                        let output = String(decoding: accumulated, as: UTF8.self)
                        cancellationController.clearProcess()
                        continuation.resume(returning: (proc.terminationStatus, output))
                    }
                }

                do {
                    try process.run()
                } catch {
                    outputHandle.readabilityHandler = nil
                    cancellationController.clearProcess()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            cancellationController.terminateIfNeeded()
        }
    }

    nonisolated private static func appendRetainedOutput(
        _ accumulated: inout Data,
        chunk: Data,
        maximumRetainedOutputBytes: Int
    ) {
        guard maximumRetainedOutputBytes > 0 else {
            accumulated.removeAll(keepingCapacity: true)
            return
        }

        if chunk.count >= maximumRetainedOutputBytes {
            accumulated = Data(chunk.suffix(maximumRetainedOutputBytes))
            return
        }

        accumulated.append(chunk)
        let overflow = accumulated.count - maximumRetainedOutputBytes
        if overflow > 0 {
            accumulated.removeSubrange(accumulated.startIndex..<(accumulated.startIndex + overflow))
        }
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
}
