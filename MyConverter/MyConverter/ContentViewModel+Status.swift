import Foundation

extension ContentViewModel {
    struct ConversionControlState {
        let statusMessage: String
        let statusLevel: ConversionStatusLevel
        let progress: Double
        let progressText: String
        let isConverting: Bool
        let canConvert: Bool
    }

    func conversionStatus(
        for kind: MediaKind,
        validationMessage: String?,
        hintMessage: String? = nil
    ) -> (message: String, level: ConversionStatusLevel) {
        let descriptor = mediaStateDescriptor(for: kind)

        return buildConversionStatus(
            isConverting: self[keyPath: descriptor.isConverting],
            currentBatchIndex: self[keyPath: descriptor.currentBatchIndex],
            totalBatchCount: self[keyPath: descriptor.totalBatchCount],
            isAnalyzingSource: self[keyPath: descriptor.isAnalyzing],
            conversionErrorMessage: self[keyPath: descriptor.conversionErrorMessage],
            validationMessage: validationMessage,
            compatibilityWarningMessage: self[keyPath: descriptor.compatibilityWarningMessage],
            hintMessage: hintMessage
        )
    }

    func statusMessage(
        for kind: MediaKind,
        validationMessage: String?,
        hintMessage: String? = nil
    ) -> String {
        conversionStatus(
            for: kind,
            validationMessage: validationMessage,
            hintMessage: hintMessage
        ).message
    }

    func statusLevel(
        for kind: MediaKind,
        validationMessage: String?,
        hintMessage: String? = nil
    ) -> ConversionStatusLevel {
        conversionStatus(
            for: kind,
            validationMessage: validationMessage,
            hintMessage: hintMessage
        ).level
    }

    func canStartConversion(
        for kind: MediaKind,
        validationMessage: String?
    ) -> Bool {
        let descriptor = mediaStateDescriptor(for: kind)

        return canStartConversion(
            sourceURL: self[keyPath: descriptor.sourceURL],
            isConverting: self[keyPath: descriptor.isConverting],
            isAnalyzingSource: self[keyPath: descriptor.isAnalyzing],
            validationMessage: validationMessage
        )
    }

    func progressPercentageText(for kind: MediaKind) -> String {
        progressPercentageText(for: displayedProgress(for: kind))
    }

    func conversionControlState(for kind: MediaKind) -> ConversionControlState {
        let descriptor = mediaStateDescriptor(for: kind)
        let validationMessage = validationMessage(for: kind)
        let hintMessage = hintMessage(for: kind)
        let status = conversionStatus(
            for: kind,
            validationMessage: validationMessage,
            hintMessage: hintMessage
        )
        let progress = displayedProgress(for: kind)

        return ConversionControlState(
            statusMessage: status.message,
            statusLevel: status.level,
            progress: progress,
            progressText: progressPercentageText(for: progress),
            isConverting: self[keyPath: descriptor.isConverting],
            canConvert: canStartConversion(for: kind, validationMessage: validationMessage)
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
