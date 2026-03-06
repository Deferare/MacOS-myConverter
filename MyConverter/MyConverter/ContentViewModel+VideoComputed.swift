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
        conversionStatus.message
    }

    var conversionStatusLevel: ConversionStatusLevel {
        conversionStatus.level
    }

    private var conversionStatus: (message: String, level: ConversionStatusLevel) {
        conversionStatus(
            for: .video,
            validationMessage: videoSettingsValidationMessage
        )
    }
}
