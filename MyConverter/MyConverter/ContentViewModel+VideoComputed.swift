import Foundation

extension ContentViewModel {
    var canConvert: Bool {
        canStartConversion(for: .video, validationMessage: videoSettingsValidationMessage)
    }

    var selectedVideoSourceURLs: [URL] {
        selectedSourceURLs(for: .video)
    }

    var selectedVideoFileCount: Int {
        selectedFileCount(for: .video)
    }

    var displayedConversionProgress: Double {
        displayedProgress(for: .video)
    }

    var progressPercentageText: String {
        progressPercentageText(for: .video)
    }

    var conversionStatusMessage: String {
        statusMessage(for: .video, validationMessage: videoSettingsValidationMessage)
    }

    var conversionStatusLevel: ConversionStatusLevel {
        statusLevel(for: .video, validationMessage: videoSettingsValidationMessage)
    }
}
