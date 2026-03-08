import Foundation

extension ContentViewModel {
    struct OutputFormatDescriptor<Format> {
        let sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let availableFormats: ReferenceWritableKeyPath<ContentViewModel, [Format]>
        let selectedFormat: ReferenceWritableKeyPath<ContentViewModel, Format>
        let placeholderFormats: () -> [Format]
        let formatNormalizedID: (Format) -> String
        let preferredSelection: ([Format]) -> Format?
    }

    func makeOutputFormatDescriptor<Format>(
        sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        availableFormats: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        selectedFormat: ReferenceWritableKeyPath<ContentViewModel, Format>,
        placeholderFormats: @escaping () -> [Format],
        formatNormalizedID: @escaping (Format) -> String,
        preferredSelection: @escaping ([Format]) -> Format?
    ) -> OutputFormatDescriptor<Format> {
        OutputFormatDescriptor(
            sourceURL: sourceURL,
            availableFormats: availableFormats,
            selectedFormat: selectedFormat,
            placeholderFormats: placeholderFormats,
            formatNormalizedID: formatNormalizedID,
            preferredSelection: preferredSelection
        )
    }

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

    func videoOutputFormatDescriptor() -> OutputFormatDescriptor<VideoFormatOption> {
        makeOutputFormatDescriptor(
            sourceURL: \.sourceURL,
            availableFormats: \.availableOutputFormats,
            selectedFormat: \.selectedOutputFormat,
            placeholderFormats: { ContentViewModelSupport.placeholderVideoFormats() },
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: VideoFormatOption.defaultSelection(from:)
        )
    }

    func imageOutputFormatDescriptor() -> OutputFormatDescriptor<ImageFormatOption> {
        makeOutputFormatDescriptor(
            sourceURL: \.imageSourceURL,
            availableFormats: \.availableImageOutputFormats,
            selectedFormat: \.selectedImageOutputFormat,
            placeholderFormats: { ContentViewModelSupport.placeholderImageFormats() },
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: { $0.first }
        )
    }

    func audioOutputFormatDescriptor() -> OutputFormatDescriptor<AudioFormatOption> {
        makeOutputFormatDescriptor(
            sourceURL: \.audioSourceURL,
            availableFormats: \.availableAudioOutputFormats,
            selectedFormat: \.selectedAudioOutputFormat,
            placeholderFormats: { ContentViewModelSupport.placeholderAudioFormats() },
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: AudioFormatOption.defaultSelection(from:)
        )
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

    func availableOutputFormatOptions<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> [Format] {
        defaultedOutputFormats(
            sourceURL: self[keyPath: descriptor.sourceURL],
            availableFormats: self[keyPath: descriptor.availableFormats],
            fallbackFormats: descriptor.placeholderFormats
        )
    }

    func isSelectedOutputFormatAvailable<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> Bool {
        let selectedFormat = self[keyPath: descriptor.selectedFormat]
        return self[keyPath: descriptor.availableFormats].contains {
            descriptor.formatNormalizedID($0) == descriptor.formatNormalizedID(selectedFormat)
        }
    }

    func ensureSelectedOutputFormatIsAvailable<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) {
        ensureSelectedFormatIsAvailable(
            options: availableOutputFormatOptions(using: descriptor),
            selectedFormatKeyPath: descriptor.selectedFormat,
            formatNormalizedID: descriptor.formatNormalizedID,
            preferredSelection: descriptor.preferredSelection
        )
    }

    func applyStoredSourceSettings<Format>(
        applyingFlagKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        formatDescriptor: OutputFormatDescriptor<Format>,
        applyAdditionalSettings: () -> Void,
        postApply: () -> Void
    ) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: applyingFlagKeyPath,
            storedFormatID: storedFormatID,
            normalizeStoredID: normalizeStoredID,
            options: availableOutputFormatOptions(using: formatDescriptor),
            selectedFormatKeyPath: formatDescriptor.selectedFormat,
            formatNormalizedID: formatDescriptor.formatNormalizedID,
            applyAdditionalSettings: applyAdditionalSettings,
            postApply: postApply
        )
    }
}
