import Foundation

extension ContentViewModel.MediaKind {
    func applyConversionError(
        _ error: Error,
        in viewModel: ContentViewModel,
        logPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        includeDebugInfo: Bool = false
    ) {
        let descriptor = mediaStateDescriptor
        if treatExportCancellationAsCancelled, case ConversionError.exportCancelled = error {
            viewModel[keyPath: descriptor.conversionErrorMessage] = nil
            return
        }

        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        viewModel[keyPath: descriptor.conversionErrorMessage] = message

        if includeDebugInfo, let conversionError = error as? ConversionError {
            print("\(logPrefix): \(conversionError.debugInfo)")
        } else {
            print("\(logPrefix): \(message)")
        }
    }
}
