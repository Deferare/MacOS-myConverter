import Foundation

extension ContentViewModel {
    func unavailableOptionMessage<Option: Equatable>(
        _ selectedOption: Option,
        in availableOptions: [Option],
        message: String
    ) -> String? {
        guard !availableOptions.contains(selectedOption) else { return nil }
        return message
    }

    func unavailableSelectedOptionMessage<Option: Equatable>(
        _ selectedOption: Option,
        in availableOptions: [Option],
        named optionName: String
    ) -> String? {
        unavailableOptionMessage(
            selectedOption,
            in: availableOptions,
            message: "Selected \(optionName) is not available for this format."
        )
    }

    func unavailableSelectedAudioEncoderMessage(_ selection: AudioEncodingSelectionState) -> String? {
        unavailableSelectedOptionMessage(
            selection.selectedEncoder,
            in: selection.encoderOptions,
            named: "audio encoder"
        )
    }

    func audioHintMessage() -> String? {
        MediaKind.audio.compatibilityHintMessage(in: self)
    }

    func audioValidationMessage() -> String? {
        MediaKind.audio.outputSettingsValidationMessage(
            in: self,
            formatDescriptor: Self.audioOutputFormatDescriptor,
            unavailableMessage: "Selected output format is not available for this source."
        ) {
            unavailableSelectedAudioEncoderMessage(audioOutputEncodingSelectionState)
        }
    }

    func validateAudioSourceOutputSettings(_ sourceURL: URL) async -> String? {
        await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedOutputFormatNormalizedID(
                using: Self.audioOutputFormatDescriptor
            ),
            unavailableMessage: "Selected output format is not available for this source.",
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: Self.audioOutputFormatDescriptor.formatNormalizedID
        )
    }

    func validatePreparedAudioSourceOutputSettings(
        source: PreparedSourceConversion,
        environment: BatchExecutionEnvironment
    ) async -> String? {
        guard let cached = environment.preparedAudioCapabilities[source.sourceID] else {
            return await validateAudioSourceOutputSettings(source.sourceURL)
        }

        return validateCachedOutputFormatAvailability(
            capabilities: cached,
            selectedFormatNormalizedID: selectedOutputFormatNormalizedID(
                using: Self.audioOutputFormatDescriptor
            ),
            unavailableMessage: "Selected output format is not available for this source.",
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID }
        )
    }
}
