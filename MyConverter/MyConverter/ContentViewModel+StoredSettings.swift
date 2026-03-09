import Foundation

extension ContentViewModel {
    struct OutputFormatDescriptor<Format> {
        let kind: MediaKind
        let sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let availableFormats: ReferenceWritableKeyPath<ContentViewModel, [Format]>
        let selectedFormat: ReferenceWritableKeyPath<ContentViewModel, Format>
        let placeholderFormats: () -> [Format]
        let formatNormalizedID: (Format) -> String
        let formatDisplayName: (Format) -> String
        let formatFileExtension: (Format) -> String
        let preferredSelection: ([Format]) -> Format?
    }

    func makeOutputFormatDescriptor<Format>(
        kind: MediaKind,
        sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        availableFormats: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        selectedFormat: ReferenceWritableKeyPath<ContentViewModel, Format>,
        placeholderFormats: @escaping () -> [Format],
        formatNormalizedID: @escaping (Format) -> String,
        formatDisplayName: @escaping (Format) -> String,
        formatFileExtension: @escaping (Format) -> String,
        preferredSelection: @escaping ([Format]) -> Format?
    ) -> OutputFormatDescriptor<Format> {
        OutputFormatDescriptor(
            kind: kind,
            sourceURL: sourceURL,
            availableFormats: availableFormats,
            selectedFormat: selectedFormat,
            placeholderFormats: placeholderFormats,
            formatNormalizedID: formatNormalizedID,
            formatDisplayName: formatDisplayName,
            formatFileExtension: formatFileExtension,
            preferredSelection: preferredSelection
        )
    }

    func outputFormatValue<Format, Value>(
        using descriptor: OutputFormatDescriptor<Format>,
        _ keyPath: KeyPath<OutputFormatDescriptor<Format>, ReferenceWritableKeyPath<ContentViewModel, Value>>
    ) -> Value {
        self[keyPath: descriptor[keyPath: keyPath]]
    }

    func setOutputFormatValue<Format, Value>(
        using descriptor: OutputFormatDescriptor<Format>,
        _ keyPath: KeyPath<OutputFormatDescriptor<Format>, ReferenceWritableKeyPath<ContentViewModel, Value>>,
        to newValue: Value
    ) {
        self[keyPath: descriptor[keyPath: keyPath]] = newValue
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

    func resolvedSelectedFormat<Format>(
        current: Format,
        options: [Format],
        formatNormalizedID: (Format) -> String,
        preferredSelection: ([Format]) -> Format?
    ) -> Format? {
        guard !options.isEmpty else { return nil }
        if options.contains(where: { formatNormalizedID($0) == formatNormalizedID(current) }) {
            return current
        }
        return preferredSelection(options)
    }

    func videoOutputFormatDescriptor() -> OutputFormatDescriptor<VideoFormatOption> {
        makeOutputFormatDescriptor(
            kind: .video,
            sourceURL: \.sourceURL,
            availableFormats: \.availableOutputFormats,
            selectedFormat: \.selectedOutputFormat,
            placeholderFormats: { ContentViewModelSupport.placeholderVideoFormats() },
            formatNormalizedID: { $0.normalizedID },
            formatDisplayName: { $0.displayName },
            formatFileExtension: { $0.fileExtension },
            preferredSelection: VideoFormatOption.defaultSelection(from:)
        )
    }

    func imageOutputFormatDescriptor() -> OutputFormatDescriptor<ImageFormatOption> {
        makeOutputFormatDescriptor(
            kind: .image,
            sourceURL: \.imageSourceURL,
            availableFormats: \.availableImageOutputFormats,
            selectedFormat: \.selectedImageOutputFormat,
            placeholderFormats: { ContentViewModelSupport.placeholderImageFormats() },
            formatNormalizedID: { $0.normalizedID },
            formatDisplayName: { $0.displayName },
            formatFileExtension: { $0.fileExtension },
            preferredSelection: { $0.first }
        )
    }

    func audioOutputFormatDescriptor() -> OutputFormatDescriptor<AudioFormatOption> {
        makeOutputFormatDescriptor(
            kind: .audio,
            sourceURL: \.audioSourceURL,
            availableFormats: \.availableAudioOutputFormats,
            selectedFormat: \.selectedAudioOutputFormat,
            placeholderFormats: { ContentViewModelSupport.placeholderAudioFormats() },
            formatNormalizedID: { $0.normalizedID },
            formatDisplayName: { $0.displayName },
            formatFileExtension: { $0.fileExtension },
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
            sourceURL: outputFormatValue(using: descriptor, \.sourceURL),
            availableFormats: outputFormatValue(using: descriptor, \.availableFormats),
            fallbackFormats: descriptor.placeholderFormats
        )
    }

    func isSelectedOutputFormatAvailable<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> Bool {
        let selectedFormat = outputFormatValue(using: descriptor, \.selectedFormat)
        return outputFormatValue(using: descriptor, \.availableFormats).contains {
            descriptor.formatNormalizedID($0) == descriptor.formatNormalizedID(selectedFormat)
        }
    }

    func selectedOutputFormatNormalizedID<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> String {
        descriptor.formatNormalizedID(outputFormatValue(using: descriptor, \.selectedFormat))
    }

    func selectedOutputFormatDisplayName<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> String {
        descriptor.formatDisplayName(outputFormatValue(using: descriptor, \.selectedFormat))
    }

    func selectedOutputFormatFileExtension<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> String {
        descriptor.formatFileExtension(outputFormatValue(using: descriptor, \.selectedFormat))
    }

    func selectedOutputFormatLabel<Format>(
        using descriptor: OutputFormatDescriptor<Format>
    ) -> String {
        "\(selectedOutputFormatDisplayName(using: descriptor)) (.\(selectedOutputFormatFileExtension(using: descriptor)))"
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

    func applyAvailableOutputFormats<Format>(
        _ formats: [Format],
        using descriptor: OutputFormatDescriptor<Format>,
        postApply: () -> Void = {}
    ) {
        let resolvedSelection = resolvedSelectedFormat(
            current: outputFormatValue(using: descriptor, \.selectedFormat),
            options: formats,
            formatNormalizedID: descriptor.formatNormalizedID,
            preferredSelection: descriptor.preferredSelection
        )

        switch descriptor.kind {
        case .video:
            guard let resolvedFormats = formats as? [VideoFormatOption] else { return }
            updateState(\.videoRuntimeState) { state in
                state.media.availableOutputFormats = resolvedFormats
            }
            if let selected = resolvedSelection as? VideoFormatOption {
                updateState(\.videoOptionsState) { state in
                    state.selectedOutputFormat = selected
                }
            }
        case .image:
            guard let resolvedFormats = formats as? [ImageFormatOption] else { return }
            updateState(\.imageRuntimeState) { state in
                state.media.availableOutputFormats = resolvedFormats
            }
            if let selected = resolvedSelection as? ImageFormatOption {
                updateState(\.imageOptionsState) { state in
                    state.selectedOutputFormat = selected
                }
            }
        case .audio:
            guard let resolvedFormats = formats as? [AudioFormatOption] else { return }
            updateState(\.audioRuntimeState) { state in
                state.media.availableOutputFormats = resolvedFormats
            }
            if let selected = resolvedSelection as? AudioFormatOption {
                updateState(\.audioOptionsState) { state in
                    state.selectedOutputFormat = selected
                }
            }
        }

        postApply()
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
