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

    func withSettingsApplicationFlag(
        _ keyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        operation: () -> Void
    ) {
        self[keyPath: keyPath] = true
        defer { self[keyPath: keyPath] = false }
        operation()
    }

    static let videoOutputFormatDescriptorValue = OutputFormatDescriptor(
        sourceURL: \.videoRuntimeState.media.sourceURL,
        availableFormats: \.videoRuntimeState.media.availableOutputFormats,
        selectedFormat: \.videoOptionsState.selectedOutputFormat,
        placeholderFormats: { ContentViewModelSupport.placeholderVideoFormats() },
        formatNormalizedID: { $0.normalizedID },
        formatDisplayName: { $0.displayName },
        formatFileExtension: { $0.fileExtension },
        preferredSelection: VideoFormatOption.defaultSelection(from:)
    )

    static let imageOutputFormatDescriptorValue = OutputFormatDescriptor(
        sourceURL: \.imageRuntimeState.media.sourceURL,
        availableFormats: \.imageRuntimeState.media.availableOutputFormats,
        selectedFormat: \.imageOptionsState.selectedOutputFormat,
        placeholderFormats: { ContentViewModelSupport.placeholderImageFormats() },
        formatNormalizedID: { $0.normalizedID },
        formatDisplayName: { $0.displayName },
        formatFileExtension: { $0.fileExtension },
        preferredSelection: { $0.first }
    )

    static let audioOutputFormatDescriptorValue = OutputFormatDescriptor(
        sourceURL: \.audioRuntimeState.media.sourceURL,
        availableFormats: \.audioRuntimeState.media.availableOutputFormats,
        selectedFormat: \.audioOptionsState.selectedOutputFormat,
        placeholderFormats: { ContentViewModelSupport.placeholderAudioFormats() },
        formatNormalizedID: { $0.normalizedID },
        formatDisplayName: { $0.displayName },
        formatFileExtension: { $0.fileExtension },
        preferredSelection: AudioFormatOption.defaultSelection(from:)
    )
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
        let options = availableOptions(in: viewModel)
        guard !options.isEmpty else { return }
        let current = selectedFormatValue(in: viewModel)
        guard !options.contains(where: { formatNormalizedID($0) == formatNormalizedID(current) }),
              let preferred = preferredSelection(options) else {
            return
        }
        viewModel[keyPath: selectedFormat] = preferred
    }

    func applyAvailableFormats(
        _ formats: [Format],
        to viewModel: ContentViewModel,
        postApply: () -> Void = {}
    ) {
        let resolvedSelection: Format?
        if formats.isEmpty {
            resolvedSelection = nil
        } else {
            let current = selectedFormatValue(in: viewModel)
            if formats.contains(where: { formatNormalizedID($0) == formatNormalizedID(current) }) {
                resolvedSelection = current
            } else {
                resolvedSelection = preferredSelection(formats)
            }
        }

        viewModel[keyPath: availableFormats] = formats
        if let selected = resolvedSelection {
            viewModel[keyPath: selectedFormat] = selected
        }

        postApply()
    }

    func applyStoredSettings(
        applyingFlagKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        to viewModel: ContentViewModel,
        applyAdditionalSettings: () -> Void,
        postApply: () -> Void
    ) {
        viewModel.withSettingsApplicationFlag(applyingFlagKeyPath) {
            if let normalizedStoredID = normalizeStoredID(storedFormatID),
               let matchingFormat = availableOptions(in: viewModel).first(
                    where: { formatNormalizedID($0) == normalizedStoredID }
               ) {
                viewModel[keyPath: selectedFormat] = matchingFormat
            }
            applyAdditionalSettings()
        }
        postApply()
    }
}
