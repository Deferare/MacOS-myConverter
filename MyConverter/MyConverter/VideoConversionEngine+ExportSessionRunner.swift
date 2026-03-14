import AVFoundation
import Foundation

extension VideoConversionEngine {
    static func export(
        _ session: AVAssetExportSession,
        to outputURL: URL,
        as outputFileType: AVFileType,
        preset: String,
        onProgress: @escaping ProgressHandler
    ) async throws {
        await onProgress(0)
        let token = PerformanceSignpost.begin("VideoEncode", message: preset)

        let progressTask = Task {
            for await state in session.states(updateInterval: 0.05) {
                if Task.isCancelled {
                    break
                }

                switch state {
                case .pending, .waiting:
                    break
                case .exporting(let progress):
                    let fractionCompleted = min(max(progress.fractionCompleted, 0), 1)
                    await onProgress(fractionCompleted)
                @unknown default:
                    break
                }
            }
        }
        defer {
            progressTask.cancel()
        }

        do {
            try await session.export(to: outputURL, as: outputFileType)
            PerformanceSignpost.end("VideoEncode", token: token, message: preset)
            await onProgress(1)
        } catch {
            if error is CancellationError {
                PerformanceSignpost.end("VideoEncode", token: token, message: "cancelled")
            } else {
                PerformanceSignpost.end("VideoEncode", token: token, message: "failed")
            }
            try rethrowIfExportCancelled(error)
            throw ConversionError.exportFailed(underlying: error, preset: preset)
        }
    }
}
