import Foundation

extension ContentViewModel {
    func nonEmptyMessage(_ message: String?) -> String? {
        guard let message, !message.isEmpty else { return nil }
        return message
    }

    func firstNonEmptyMessage(_ messages: String?...) -> String? {
        for message in messages {
            if let message = nonEmptyMessage(message) {
                return message
            }
        }
        return nil
    }

    func compatibilityHintMessage(for kind: MediaKind) -> String? {
        let descriptor = mediaStateDescriptor(for: kind)
        return nonEmptyMessage(self[keyPath: descriptor.compatibilityWarningMessage])
    }

    func outputSettingsValidationMessage<Format>(
        for kind: MediaKind,
        formatDescriptor: OutputFormatDescriptor<Format>,
        unavailableMessage: String,
        additionalValidation: () -> String? = { nil }
    ) -> String? {
        let descriptor = mediaStateDescriptor(for: kind)

        if let compatibilityError = nonEmptyMessage(self[keyPath: descriptor.compatibilityErrorMessage]) {
            return compatibilityError
        }

        if self[keyPath: descriptor.sourceURL] != nil &&
            !isSelectedOutputFormatAvailable(using: formatDescriptor) {
            return unavailableMessage
        }

        return additionalValidation()
    }

    func selectedOutputFormatNormalizedID<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> String {
        descriptor.formatNormalizedID(self[keyPath: descriptor.selectedFormat])
    }

    func validateSelectedOutputFormatAvailability<Capability, Format>(
        for sourceURL: URL,
        formatDescriptor: OutputFormatDescriptor<Format>,
        unavailableMessage: String,
        fetchCapabilities: (URL) async -> Capability,
        availableFormats: (Capability) -> [Format],
        errorMessage: (Capability) -> String?,
        additionalValidation: (Capability) -> String? = { _ in nil }
    ) async -> String? {
        await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedOutputFormatNormalizedID(using: formatDescriptor),
            unavailableMessage: unavailableMessage,
            fetchCapabilities: fetchCapabilities,
            availableFormats: availableFormats,
            errorMessage: errorMessage,
            formatNormalizedID: formatDescriptor.formatNormalizedID,
            additionalValidation: additionalValidation
        )
    }

    func validateOutputFormatAvailability<Capability, Format>(
        for sourceURL: URL,
        selectedFormatNormalizedID: String,
        unavailableMessage: String,
        fetchCapabilities: (URL) async -> Capability,
        availableFormats: (Capability) -> [Format],
        errorMessage: (Capability) -> String?,
        formatNormalizedID: (Format) -> String,
        additionalValidation: (Capability) -> String? = { _ in nil }
    ) async -> String? {
        let capabilities = await fetchCapabilities(sourceURL)
        if let error = errorMessage(capabilities) {
            return error
        }

        let isFormatAvailable = availableFormats(capabilities).contains {
            formatNormalizedID($0) == selectedFormatNormalizedID
        }
        if !isFormatAvailable {
            return unavailableMessage
        }

        if let extraValidationMessage = additionalValidation(capabilities) {
            return extraValidationMessage
        }

        return nil
    }
}
