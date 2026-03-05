import Foundation

extension ProcessCommandRunner {
    nonisolated static func runCommand(
        path: String,
        arguments: [String],
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
                        accumulated.append(data)
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
                            accumulated.append(trailingData)
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

                        let output = String(data: accumulated, encoding: .utf8) ?? ""
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
