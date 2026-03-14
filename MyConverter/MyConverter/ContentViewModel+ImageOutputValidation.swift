import Foundation

extension ContentViewModel {
    func imageAnimationExportValidationMessage(isAnimated: Bool) -> String? {
        guard isAnimated,
              imageOptionsState.preserveAnimation,
              imageOptionsState.selectedOutputFormat.supportsAnimation,
              !ImageConversionEngine.isFFmpegAvailable() else {
            return nil
        }

        return "Animated output requires ffmpeg for the selected format."
    }

    func imageHintMessage() -> String? {
        firstNonEmptyMessage(
            imageSourceIsAnimated && !imageOptionsState.selectedOutputFormat.supportsAnimation
                ? "This format exports only the first frame for animated sources."
                : nil,
            shouldShowPreserveAnimationOption && !ImageConversionEngine.isFFmpegAvailable()
                ? "ffmpeg is required to preserve animation."
                : nil
        )
    }

    func imageValidationMessage() -> String? {
        MediaKind.image.outputSettingsValidationMessage(
            in: self,
            formatDescriptor: Self.imageOutputFormatDescriptor,
            unavailableMessage: "Selected output format is not available for this source."
        ) {
            imageAnimationExportValidationMessage(isAnimated: imageSourceIsAnimated)
        }
    }

    func validateImageSourceOutputSettings(_ sourceURL: URL) async -> String? {
        await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedOutputFormatNormalizedID(
                using: Self.imageOutputFormatDescriptor
            ),
            unavailableMessage: "Selected output format is not available for this source.",
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: Self.imageOutputFormatDescriptor.formatNormalizedID,
            additionalValidation: { capabilities in
                imageAnimationExportValidationMessage(isAnimated: capabilities.frameCount > 1)
            }
        )
    }

    func validatePreparedImageSourceOutputSettings(
        source: PreparedSourceConversion,
        environment: BatchExecutionEnvironment
    ) async -> String? {
        guard let cached = environment.preparedImageCapabilities[source.sourceID] else {
            return await validateImageSourceOutputSettings(source.sourceURL)
        }

        return validateCachedOutputFormatAvailability(
            capabilities: cached,
            selectedFormatNormalizedID: selectedOutputFormatNormalizedID(
                using: Self.imageOutputFormatDescriptor
            ),
            unavailableMessage: "Selected output format is not available for this source.",
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            additionalValidation: { capabilities in
                imageAnimationExportValidationMessage(isAnimated: capabilities.frameCount > 1)
            }
        )
    }
}
