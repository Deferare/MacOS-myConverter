import Foundation

extension ContentViewModel.MediaKind {
    func applyConversionError(
        _ error: Error,
        in viewModel: ContentViewModel,
        logPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        includeDebugInfo: Bool = false
    ) {
        if treatExportCancellationAsCancelled, case ConversionError.exportCancelled = error {
            setConversionErrorMessage(nil, in: viewModel)
            return
        }

        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        setConversionErrorMessage(message, in: viewModel)

        if includeDebugInfo, let conversionError = error as? ConversionError {
            print("\(logPrefix): \(conversionError.debugInfo)")
        } else {
            print("\(logPrefix): \(message)")
        }
    }
}
