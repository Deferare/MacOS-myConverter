import Foundation

extension ContentViewModel {
    func withSettingsApplicationFlag(
        _ keyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        operation: () -> Void
    ) {
        self[keyPath: keyPath] = true
        defer { self[keyPath: keyPath] = false }
        operation()
    }

    func outputFormatValue<Format, Value>(
        using descriptor: OutputFormatDescriptor<Format>,
        _ keyPath: KeyPath<OutputFormatDescriptor<Format>, ReferenceWritableKeyPath<ContentViewModel, Value>>
    ) -> Value {
        self[keyPath: descriptor[keyPath: keyPath]]
    }

    func selectedOutputFormat<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> Format {
        outputFormatValue(using: descriptor, \.selectedFormat)
    }

    func availableOutputFormatOptions<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> [Format] {
        let sourceURL = outputFormatValue(using: descriptor, \.sourceURL)
        let availableFormats = outputFormatValue(using: descriptor, \.availableFormats)
        if sourceURL == nil && availableFormats.isEmpty {
            return descriptor.placeholderFormats()
        }
        return availableFormats
    }

    func isSelectedOutputFormatAvailable<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> Bool {
        let selectedFormat = selectedOutputFormat(using: descriptor)
        return outputFormatValue(using: descriptor, \.availableFormats).contains {
            descriptor.formatNormalizedID($0) == descriptor.formatNormalizedID(selectedFormat)
        }
    }

    func selectedOutputFormatNormalizedID<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> String {
        descriptor.formatNormalizedID(selectedOutputFormat(using: descriptor))
    }

    func selectedOutputFormatDisplayName<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> String {
        descriptor.formatDisplayName(selectedOutputFormat(using: descriptor))
    }

    func selectedOutputFormatFileExtension<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> String {
        descriptor.formatFileExtension(selectedOutputFormat(using: descriptor))
    }

    func selectedOutputFormatLabel<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> String {
        "\(selectedOutputFormatDisplayName(using: descriptor)) (.\(selectedOutputFormatFileExtension(using: descriptor)))"
    }

    func ensureSelectedOutputFormatIsAvailable<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) {
        let options = availableOutputFormatOptions(using: descriptor)
        guard !options.isEmpty else { return }
        let current = selectedOutputFormat(using: descriptor)
        guard !options.contains(where: {
            descriptor.formatNormalizedID($0) == descriptor.formatNormalizedID(current)
        }),
        let preferred = descriptor.preferredSelection(options) else {
            return
        }
        self[keyPath: descriptor.selectedFormat] = preferred
    }

    func applyAvailableOutputFormats<Format>(
        _ formats: [Format],
        using descriptor: OutputFormatDescriptor<Format>,
        postApply: () -> Void = {}
    ) {
        let resolvedSelection: Format?
        if formats.isEmpty {
            resolvedSelection = nil
        } else {
            let current = selectedOutputFormat(using: descriptor)
            if formats.contains(where: {
                descriptor.formatNormalizedID($0) == descriptor.formatNormalizedID(current)
            }) {
                resolvedSelection = current
            } else {
                resolvedSelection = descriptor.preferredSelection(formats)
            }
        }

        self[keyPath: descriptor.availableFormats] = formats
        if let selected = resolvedSelection {
            self[keyPath: descriptor.selectedFormat] = selected
        }

        postApply()
    }

    func applyStoredOutputFormatSettings<Format>(
        using descriptor: OutputFormatDescriptor<Format>,
        applyingFlagKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        applyAdditionalSettings: () -> Void,
        postApply: () -> Void
    ) {
        withSettingsApplicationFlag(applyingFlagKeyPath) {
            if let normalizedStoredID = normalizeStoredID(storedFormatID),
               let matchingFormat = availableOutputFormatOptions(using: descriptor).first(
                    where: { descriptor.formatNormalizedID($0) == normalizedStoredID }
               ) {
                self[keyPath: descriptor.selectedFormat] = matchingFormat
            }
            applyAdditionalSettings()
        }
        postApply()
    }
}
