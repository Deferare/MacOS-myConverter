import Foundation

extension ContentViewModel {
    func buildConversionStatus(
        isConverting: Bool,
        currentBatchIndex: Int,
        totalBatchCount: Int,
        isAnalyzingSource: Bool,
        conversionErrorMessage: String?,
        validationMessage: String?,
        compatibilityWarningMessage: String?,
        hintMessage: String? = nil
    ) -> (message: String, level: ConversionStatusLevel) {
        if isConverting {
            if totalBatchCount > 1 {
                let current = max(1, currentBatchIndex)
                return ("Converting file \(current)/\(totalBatchCount)...", .normal)
            }
            return ("Conversion in progress...", .normal)
        }

        if isAnalyzingSource {
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

    func displayedProgress(isConverting: Bool, rawProgress: Double) -> Double {
        let progress = isConverting ? rawProgress : 0
        return progress < 0.01 ? 0 : progress
    }

    func progressPercentageText(for progress: Double) -> String {
        let percent = Int((progress * 100).rounded())
        return "\(max(0, min(percent, 100)))%"
    }

    func canStartConversion(
        sourceURL: URL?,
        isConverting: Bool,
        isAnalyzingSource: Bool,
        validationMessage: String?,
        selectedFormatAvailable: Bool = true
    ) -> Bool {
        sourceURL != nil &&
            !isConverting &&
            !isAnalyzingSource &&
            validationMessage == nil &&
            selectedFormatAvailable
    }

    func defaultedOutputFormats<Format>(
        sourceURL: URL?,
        availableFormats: [Format],
        fallbackFormats: () -> [Format]
    ) -> [Format] {
        if sourceURL == nil && availableFormats.isEmpty {
            return fallbackFormats()
        }
        return availableFormats
    }
}
