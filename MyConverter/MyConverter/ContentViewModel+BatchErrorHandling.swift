import Foundation

extension ContentViewModel {
    func applyConversionError(
        _ error: Error,
        for kind: MediaKind,
        logPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        includeDebugInfo: Bool = false
    ) {
        if treatExportCancellationAsCancelled, case ConversionError.exportCancelled = error {
            setConversionErrorMessage(nil, for: kind)
            return
        }

        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        setConversionErrorMessage(message, for: kind)

        if includeDebugInfo, let conversionError = error as? ConversionError {
            print("\(logPrefix): \(conversionError.debugInfo)")
        } else {
            print("\(logPrefix): \(message)")
        }
    }
}
