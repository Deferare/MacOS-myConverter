import Foundation

extension ContentViewModel {
    enum PreparedSourceOutputValidationResult {
        case handled(String?)
        case unavailable
    }

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
        let capabilities = await SecurityScopedResourceAccess.withAccess(to: sourceURL) {
            await fetchCapabilities(sourceURL)
        }
        return validateResolvedOutputFormatAvailability(
            capabilities: capabilities,
            selectedFormatNormalizedID: selectedFormatNormalizedID,
            unavailableMessage: unavailableMessage,
            availableFormats: availableFormats,
            errorMessage: errorMessage,
            formatNormalizedID: formatNormalizedID,
            additionalValidation: additionalValidation
        )
    }

    func validateResolvedOutputFormatAvailability<Capability, Format>(
        capabilities: Capability,
        selectedFormatNormalizedID: String,
        unavailableMessage: String,
        availableFormats: (Capability) -> [Format],
        errorMessage: (Capability) -> String?,
        formatNormalizedID: (Format) -> String,
        additionalValidation: (Capability) -> String? = { _ in nil }
    ) -> String? {
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

    func validateCachedOutputFormatAvailability<Capability, Format>(
        capabilities: Capability,
        selectedFormatNormalizedID: String,
        unavailableMessage: String,
        availableFormats: (Capability) -> [Format],
        errorMessage: (Capability) -> String?,
        formatNormalizedID: (Format) -> String,
        additionalValidation: (Capability) -> String? = { _ in nil }
    ) -> String? {
        validateResolvedOutputFormatAvailability(
            capabilities: capabilities,
            selectedFormatNormalizedID: selectedFormatNormalizedID,
            unavailableMessage: unavailableMessage,
            availableFormats: availableFormats,
            errorMessage: errorMessage,
            formatNormalizedID: formatNormalizedID,
            additionalValidation: additionalValidation
        )
    }
}
