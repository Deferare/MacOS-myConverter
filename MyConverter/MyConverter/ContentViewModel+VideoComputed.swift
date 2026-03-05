import Foundation

extension ContentViewModel {
    var canConvert: Bool {
        canStartConversion(
            sourceURL: sourceURL,
            isConverting: isConverting,
            isAnalyzingSource: isAnalyzingSource,
            validationMessage: videoSettingsValidationMessage
        )
    }

    var selectedVideoSourceURLs: [URL] {
        guard let sourceURL else { return [] }
        return [sourceURL] + queuedSourceURLs
    }

    var selectedVideoFileCount: Int {
        selectedVideoSourceURLs.count
    }

    var displayedConversionProgress: Double {
        displayedProgress(isConverting: isConverting, rawProgress: conversionProgress)
    }

    var progressPercentageText: String {
        progressPercentageText(for: displayedConversionProgress)
    }

    var conversionStatusMessage: String {
        conversionStatus.message
    }

    var conversionStatusLevel: ConversionStatusLevel {
        conversionStatus.level
    }

    private var conversionStatus: (message: String, level: ConversionStatusLevel) {
        buildConversionStatus(
            isConverting: isConverting,
            currentBatchIndex: currentVideoBatchIndex,
            totalBatchCount: totalVideoBatchCount,
            isAnalyzingSource: isAnalyzingSource,
            conversionErrorMessage: conversionErrorMessage,
            validationMessage: videoSettingsValidationMessage,
            compatibilityWarningMessage: sourceCompatibilityWarningMessage
        )
    }
}
