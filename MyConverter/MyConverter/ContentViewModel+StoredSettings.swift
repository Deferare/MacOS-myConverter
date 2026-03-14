import Foundation

extension ContentViewModel {
    struct OutputFormatDescriptor<Format> {
        let sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let availableFormats: ReferenceWritableKeyPath<ContentViewModel, [Format]>
        let selectedFormat: ReferenceWritableKeyPath<ContentViewModel, Format>
        let placeholderFormats: () -> [Format]
        let formatNormalizedID: (Format) -> String
        let formatDisplayName: (Format) -> String
        let formatFileExtension: (Format) -> String
        let preferredSelection: ([Format]) -> Format?
    }

    static func makeOutputFormatDescriptor<Format>(
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

    static let videoOutputFormatDescriptorValue = makeOutputFormatDescriptor(
            sourceURL: \.videoRuntimeState.media.sourceURL,
            availableFormats: \.videoRuntimeState.media.availableOutputFormats,
            selectedFormat: \.videoOptionsState.selectedOutputFormat,
            placeholderFormats: { ContentViewModelSupport.placeholderVideoFormats() },
            formatNormalizedID: { $0.normalizedID },
            formatDisplayName: { $0.displayName },
            formatFileExtension: { $0.fileExtension },
            preferredSelection: VideoFormatOption.defaultSelection(from:)
        )

    static let imageOutputFormatDescriptorValue = makeOutputFormatDescriptor(
            sourceURL: \.imageRuntimeState.media.sourceURL,
            availableFormats: \.imageRuntimeState.media.availableOutputFormats,
            selectedFormat: \.imageOptionsState.selectedOutputFormat,
            placeholderFormats: { ContentViewModelSupport.placeholderImageFormats() },
            formatNormalizedID: { $0.normalizedID },
            formatDisplayName: { $0.displayName },
            formatFileExtension: { $0.fileExtension },
            preferredSelection: { $0.first }
        )

    static let audioOutputFormatDescriptorValue = makeOutputFormatDescriptor(
            sourceURL: \.audioRuntimeState.media.sourceURL,
            availableFormats: \.audioRuntimeState.media.availableOutputFormats,
            selectedFormat: \.audioOptionsState.selectedOutputFormat,
            placeholderFormats: { ContentViewModelSupport.placeholderAudioFormats() },
            formatNormalizedID: { $0.normalizedID },
            formatDisplayName: { $0.displayName },
            formatFileExtension: { $0.fileExtension },
            preferredSelection: AudioFormatOption.defaultSelection(from:)
        )

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
            options: formatDescriptor.availableOptions(in: self),
            selectedFormatKeyPath: formatDescriptor.selectedFormat,
            formatNormalizedID: formatDescriptor.formatNormalizedID,
            applyAdditionalSettings: applyAdditionalSettings,
            postApply: postApply
        )
    }
}

extension ContentViewModel.OutputFormatDescriptor {
    func value<Value>(
        in viewModel: ContentViewModel,
        _ keyPath: KeyPath<Self, ReferenceWritableKeyPath<ContentViewModel, Value>>
    ) -> Value {
        viewModel[keyPath: self[keyPath: keyPath]]
    }

    func selectedFormatValue(in viewModel: ContentViewModel) -> Format {
        value(in: viewModel, \.selectedFormat)
    }

    func availableOptions(in viewModel: ContentViewModel) -> [Format] {
        let sourceURL = value(in: viewModel, \.sourceURL)
        let availableFormats = value(in: viewModel, \.availableFormats)
        if sourceURL == nil && availableFormats.isEmpty {
            return placeholderFormats()
        }
        return availableFormats
    }

    func isSelectedFormatAvailable(in viewModel: ContentViewModel) -> Bool {
        let selectedFormat = selectedFormatValue(in: viewModel)
        return value(in: viewModel, \.availableFormats).contains {
            formatNormalizedID($0) == formatNormalizedID(selectedFormat)
        }
    }

    func selectedFormatNormalizedID(in viewModel: ContentViewModel) -> String {
        formatNormalizedID(selectedFormatValue(in: viewModel))
    }

    func selectedFormatDisplayName(in viewModel: ContentViewModel) -> String {
        formatDisplayName(selectedFormatValue(in: viewModel))
    }

    func selectedFormatFileExtension(in viewModel: ContentViewModel) -> String {
        formatFileExtension(selectedFormatValue(in: viewModel))
    }

    func selectedFormatLabel(in viewModel: ContentViewModel) -> String {
        "\(selectedFormatDisplayName(in: viewModel)) (.\(selectedFormatFileExtension(in: viewModel)))"
    }

    func ensureSelectedFormatIsAvailable(in viewModel: ContentViewModel) {
        viewModel.ensureSelectedFormatIsAvailable(
            options: availableOptions(in: viewModel),
            selectedFormatKeyPath: selectedFormat,
            formatNormalizedID: formatNormalizedID,
            preferredSelection: preferredSelection
        )
    }

    func applyAvailableFormats(
        _ formats: [Format],
        to viewModel: ContentViewModel,
        postApply: () -> Void = {}
    ) {
        let resolvedSelection = viewModel.resolvedSelectedFormat(
            current: selectedFormatValue(in: viewModel),
            options: formats,
            formatNormalizedID: formatNormalizedID,
            preferredSelection: preferredSelection
        )

        viewModel[keyPath: availableFormats] = formats
        if let selected = resolvedSelection {
            viewModel[keyPath: selectedFormat] = selected
        }

        postApply()
    }
}
