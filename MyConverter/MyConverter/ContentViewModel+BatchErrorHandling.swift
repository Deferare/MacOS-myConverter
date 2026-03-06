import Foundation

extension ContentViewModel {
    func applyConversionError(
        _ error: Error,
        for kind: MediaKind,
        logPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        includeDebugInfo: Bool = false
    ) {
        let descriptor = mediaStateDescriptor(for: kind)
        if treatExportCancellationAsCancelled, case ConversionError.exportCancelled = error {
            self[keyPath: descriptor.conversionErrorMessage] = nil
            return
        }

        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        self[keyPath: descriptor.conversionErrorMessage] = message

        if includeDebugInfo, let conversionError = error as? ConversionError {
            print("\(logPrefix): \(conversionError.debugInfo)")
        } else {
            print("\(logPrefix): \(message)")
        }
    }
}
