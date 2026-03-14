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
            canConvert = snapshot.canStartConversion(validationMessage: validationMessage)
            self.selectedFileCount = selectedFileCount
            selectedFormatLabel = kind.selectedOutputFormatLabel(in: viewModel)
            self.convertedCount = convertedCount
            showsSettings = selectedFileCount > 0
            showsResults = convertedCount > 0
            destinationHint = kind.selectedOutputDirectoryURL(in: viewModel).map {
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
                progressText: snapshot.progressText
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
}

extension ContentViewModel.MediaKind {
    func canStartConversion(
        in viewModel: ContentViewModel,
        validationMessage: String?
    ) -> Bool {
        mediaStateSnapshot(in: viewModel).canStartConversion(validationMessage: validationMessage)
    }

    func converterRenderState(in viewModel: ContentViewModel) -> ContentViewModel.ConverterRenderState {
        let snapshot = mediaStateSnapshot(in: viewModel)
        let validationMessage = validationMessage(in: viewModel)
        let status = snapshot.conversionStatus(
            validationMessage: validationMessage,
            hintMessage: hintMessage(in: viewModel)
        )

        return ContentViewModel.ConverterRenderState(
            kind: self,
            viewModel: viewModel,
            snapshot: snapshot,
            validationMessage: validationMessage,
            status: status
        )
    }
}
