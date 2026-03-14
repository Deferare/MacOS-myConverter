import Foundation

extension ContentViewModel {
    struct ConverterScreenState: Equatable {
        let isConverting: Bool
        let canConvert: Bool
        let selectedFileCount: Int
        let selectedFormatLabel: String
        let convertedCount: Int
        let showsSettings: Bool
        let showsResults: Bool
        let destinationHint: String
        let primaryActionTitle: String

        init(
            kind: MediaKind,
            viewModel: ContentViewModel,
            snapshot: MediaStateSnapshot,
            validationMessage: String?
        ) {
            let selectedFileCount = snapshot.selectedFileCount
            let convertedCount = snapshot.convertedURLs.count

            isConverting = snapshot.isConverting
            canConvert = viewModel.canStartConversion(using: snapshot, validationMessage: validationMessage)
            self.selectedFileCount = selectedFileCount
            selectedFormatLabel = kind.selectedOutputFormatLabel(in: viewModel)
            self.convertedCount = convertedCount
            showsSettings = selectedFileCount > 0
            showsResults = convertedCount > 0
            destinationHint = viewModel.selectedOutputDirectoryURL(for: kind).map {
                "Selected output folder: \(viewModel.abbreviatedOutputDirectoryPath($0))"
            } ?? "Select an output folder in Conversion Settings, or choose one after you press Start."
            primaryActionTitle = snapshot.isConverting ? "Cancel" : "Start"
        }
    }

    struct ConverterInputHeaderState: Equatable {
        let statusMessage: String
        let statusLevel: ConversionStatusLevel
        let progressText: String
        let isConverting: Bool

        init(
            snapshot: MediaStateSnapshot,
            statusMessage: String,
            statusLevel: ConversionStatusLevel,
            progressText: String
        ) {
            self.statusMessage = statusMessage
            self.statusLevel = statusLevel
            self.progressText = progressText
            isConverting = snapshot.isConverting
        }
    }

    struct ConverterRenderState: Equatable {
        let screenState: ConverterScreenState
        let inputHeaderState: ConverterInputHeaderState
        let selectedFileListState: SelectedFileListState

        init(
            kind: MediaKind,
            viewModel: ContentViewModel,
            snapshot: MediaStateSnapshot,
            validationMessage: String?,
            status: (message: String, level: ConversionStatusLevel)
        ) {
            let selectedFileCount = snapshot.selectedFileCount
            let convertedCount = snapshot.convertedURLs.count
            let resolvedStatusMessage = Self.resolvedStatusMessage(
                selectedFileCount: selectedFileCount,
                convertedCount: convertedCount,
                isConverting: snapshot.isConverting,
                status: status
            )

            screenState = ConverterScreenState(
                kind: kind,
                viewModel: viewModel,
                snapshot: snapshot,
                validationMessage: validationMessage
            )
            inputHeaderState = ConverterInputHeaderState(
                snapshot: snapshot,
                statusMessage: resolvedStatusMessage,
                statusLevel: status.level,
                progressText: viewModel.progressPercentageText(for: snapshot.displayedProgress)
            )
            selectedFileListState = SelectedFileListState(snapshot: snapshot)
        }

        private static func resolvedStatusMessage(
            selectedFileCount: Int,
            convertedCount: Int,
            isConverting: Bool,
            status: (message: String, level: ConversionStatusLevel)
        ) -> String {
            if selectedFileCount == 0 {
                return "Import files to begin."
            }

            if convertedCount > 0 && !isConverting && status.level != .error {
                return convertedCount == 1 ? "Conversion complete." : "\(convertedCount) files converted."
            }

            return status.message
        }
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

    func converterRenderState(for kind: MediaKind) -> ConverterRenderState {
        let snapshot = mediaStateSnapshot(for: kind)
        let validationMessage = validationMessage(for: kind)
        let status = conversionStatus(
            using: snapshot,
            validationMessage: validationMessage,
            hintMessage: hintMessage(for: kind)
        )

        return ConverterRenderState(
            kind: kind,
            viewModel: self,
            snapshot: snapshot,
            validationMessage: validationMessage,
            status: status
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

}
