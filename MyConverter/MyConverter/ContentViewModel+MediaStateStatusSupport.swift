import Foundation

extension ContentViewModel.MediaStateSnapshot {
    func conversionStatus(
        validationMessage: String?,
        hintMessage: String? = nil
    ) -> (message: String, level: ContentViewModel.ConversionStatusLevel) {
        if isConverting {
            if totalBatchCount > 1 {
                let current = max(1, currentBatchIndex)
                return ("Converting file \(current)/\(totalBatchCount)...", .normal)
            }
            return ("Conversion in progress...", .normal)
        }

        if isAnalyzing {
            return ("Analyzing source compatibility...", .normal)
        }

        if let conversionErrorMessage, !conversionErrorMessage.isEmpty {
            return (conversionErrorMessage, .error)
        }

        if let validationMessage {
            return (validationMessage, .error)
        }

        if let compatibilityWarningMessage, !compatibilityWarningMessage.isEmpty {
            return (compatibilityWarningMessage, .warning)
        }

        if let hintMessage, !hintMessage.isEmpty {
            return (hintMessage, .warning)
        }

        return ("Ready", .normal)
    }

    var progressText: String {
        let percent = Int((displayedProgress * 100).rounded())
        return "\(max(0, min(percent, 100)))%"
    }

    func canStartConversion(validationMessage: String?) -> Bool {
        sourceURL != nil &&
            !isConverting &&
            !isAnalyzing &&
            validationMessage == nil
    }
}
