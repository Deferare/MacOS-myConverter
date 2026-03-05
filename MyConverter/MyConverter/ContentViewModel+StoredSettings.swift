extension ContentViewModel {
    func withSettingsApplicationFlag(
        _ keyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        operation: () -> Void
    ) {
        self[keyPath: keyPath] = true
        defer { self[keyPath: keyPath] = false }
        operation()
    }

    func applyStoredFormatSelection<Format>(
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String
    ) {
        guard let normalizedStoredID = normalizeStoredID(storedFormatID),
              let matchingFormat = options.first(where: { formatNormalizedID($0) == normalizedStoredID }) else {
            return
        }
        self[keyPath: selectedFormatKeyPath] = matchingFormat
    }

    func applyStoredSourceSettings<Format>(
        applyingFlagKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String,
        applyAdditionalSettings: () -> Void,
        postApply: () -> Void
    ) {
        withSettingsApplicationFlag(applyingFlagKeyPath) {
            applyStoredFormatSelection(
                storedFormatID: storedFormatID,
                normalizeStoredID: normalizeStoredID,
                options: options,
                selectedFormatKeyPath: selectedFormatKeyPath,
                formatNormalizedID: formatNormalizedID
            )
            applyAdditionalSettings()
        }
        postApply()
    }

    func ensureSelectedFormatIsAvailable<Format>(
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String,
        preferredSelection: ([Format]) -> Format?
    ) {
        guard !options.isEmpty else { return }
        let selectedFormat = self[keyPath: selectedFormatKeyPath]
        guard !options.contains(where: { formatNormalizedID($0) == formatNormalizedID(selectedFormat) }),
              let preferredFormat = preferredSelection(options) else {
            return
        }
        self[keyPath: selectedFormatKeyPath] = preferredFormat
    }

}
