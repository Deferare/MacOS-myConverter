import Foundation

extension ContentViewModel {
    struct ConverterScreenState: Equatable {
        let statusMessage: String
        let statusLevel: ConversionStatusLevel
        let progress: Double
        let progressText: String
        let isConverting: Bool
        let canConvert: Bool
        let selectedFileCount: Int
        let selectedFormatLabel: String
        let convertedCount: Int
        let showsSettings: Bool
        let showsResults: Bool
        let destinationHint: String
        let primaryActionTitle: String
    }

    func conversionStatus(
        using snapshot: MediaStateSnapshot,
        validationMessage: String?,
        hintMessage: String? = nil
    ) -> (message: String, level: ConversionStatusLevel) {
        buildConversionStatus(
            isConverting: snapshot.isConverting,
            currentBatchIndex: snapshot.currentBatchIndex,
            totalBatchCount: snapshot.totalBatchCount,
            isAnalyzingSource: snapshot.isAnalyzing,
            conversionErrorMessage: snapshot.conversionErrorMessage,
            validationMessage: validationMessage,
            compatibilityWarningMessage: snapshot.compatibilityWarningMessage,
            hintMessage: hintMessage
        )
    }

    func canStartConversion(
        for kind: MediaKind,
        validationMessage: String?
    ) -> Bool {
        canStartConversion(
            using: mediaStateSnapshot(for: kind),
            validationMessage: validationMessage
        )
    }

    func converterScreenState(for kind: MediaKind) -> ConverterScreenState {
        let snapshot = mediaStateSnapshot(for: kind)
        let validationMessage = validationMessage(for: kind)
        let hintMessage = hintMessage(for: kind)
        let status = conversionStatus(
            using: snapshot,
            validationMessage: validationMessage,
            hintMessage: hintMessage
        )
        let selectedFileCount = selectedFileCount(for: kind)
        let convertedCount = snapshot.convertedURLs.count
        let progress = displayedProgress(for: snapshot)
        let statusMessage: String

        if selectedFileCount == 0 {
            statusMessage = "Import files to begin."
        } else if convertedCount > 0 && !snapshot.isConverting && status.level != .error {
            statusMessage = convertedCount == 1 ? "Conversion complete." : "\(convertedCount) files converted."
        } else {
            statusMessage = status.message
        }

        let primaryActionTitle: String
        if snapshot.isConverting {
            primaryActionTitle = "Cancel"
        } else {
            primaryActionTitle = "Start"
        }

        return ConverterScreenState(
            statusMessage: statusMessage,
            statusLevel: status.level,
            progress: progress,
            progressText: progressPercentageText(for: progress),
            isConverting: snapshot.isConverting,
            canConvert: canStartConversion(using: snapshot, validationMessage: validationMessage),
            selectedFileCount: selectedFileCount,
            selectedFormatLabel: selectedOutputFormatLabel(for: kind),
            convertedCount: convertedCount,
            showsSettings: selectedFileCount > 0,
            showsResults: convertedCount > 0,
            destinationHint: "Output folder is chosen after you press Start.",
            primaryActionTitle: primaryActionTitle
        )
    }

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
        using snapshot: MediaStateSnapshot,
        validationMessage: String?
    ) -> Bool {
        canStartConversion(
            sourceURL: snapshot.sourceURL,
            isConverting: snapshot.isConverting,
            isAnalyzingSource: snapshot.isAnalyzing,
            validationMessage: validationMessage
        )
    }

    func canStartConversion(
        sourceURL: URL?,
        isConverting: Bool,
        isAnalyzingSource: Bool,
        validationMessage: String?
    ) -> Bool {
        sourceURL != nil &&
            !isConverting &&
            !isAnalyzingSource &&
            validationMessage == nil
    }

    func selectedOutputFormatLabel(for kind: MediaKind) -> String {
        kind.selectedOutputFormatLabel(using: self)
    }
}
