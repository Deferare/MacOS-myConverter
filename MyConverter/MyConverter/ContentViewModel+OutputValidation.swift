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

    func compatibilityHintMessage(for kind: MediaKind) -> String? {
        let descriptor = kind.mediaStateDescriptor
        return nonEmptyMessage(self[keyPath: descriptor.compatibilityWarningMessage])
    }

    func videoFFmpegRequirementMessage() -> String? {
        guard videoEncodingSelectionState.requiresFFmpeg,
              !VideoConversionEngine.isFFmpegAvailable() else {
            return nil
        }

        return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
    }

    func customVideoBitRateValidationMessage() -> String? {
        let selection = videoEncodingSelectionState
        guard selection.shouldShowVideoBitRateOption,
              selection.selectedVideoBitRate == .custom,
              selection.normalizedCustomVideoBitRateKbps == nil else {
            return nil
        }

        return "Please enter an integer greater than 1 for Custom Bitrate (Kbps)."
    }

    func imageAnimationExportValidationMessage(isAnimated: Bool) -> String? {
        guard isAnimated,
              imageOptionsState.preserveAnimation,
              imageOptionsState.selectedOutputFormat.supportsAnimation,
              !ImageConversionEngine.isFFmpegAvailable() else {
            return nil
        }

        return "Animated output requires ffmpeg for the selected format."
    }

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

    func videoValidationMessage() -> String? {
        firstNonEmptyMessage(
            videoRuntimeState.media.sourceURL != nil ? videoFFmpegRequirementMessage() : nil,
            customVideoBitRateValidationMessage()
        ) ?? outputSettingsValidationMessage(
            for: .video,
            formatDescriptor: Self.videoOutputFormatDescriptor,
            unavailableMessage: "Selected container is not available for this source."
        ) {
            let selection = videoEncodingSelectionState
            return firstNonEmptyMessage(
                unavailableSelectedOptionMessage(
                    selection.selectedVideoEncoder,
                    in: selection.videoEncoderOptions,
                    named: "video encoder"
                ),
                selection.audioSettings.isEnabled
                    ? unavailableSelectedAudioEncoderMessage(selection.audioSettings)
                    : nil
            )
        }
    }

    func validateVideoSourceOutputSettings(_ sourceURL: URL) async -> String? {
        if let message = videoFFmpegRequirementMessage() {
            return message
        }

        return await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedOutputFormatNormalizedID(
                using: Self.videoOutputFormatDescriptor
            ),
            unavailableMessage: "Selected container is not available for this source.",
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: Self.videoOutputFormatDescriptor.formatNormalizedID
        )
    }

    func validatePreparedVideoSourceOutputSettings(
        source: PreparedSourceConversion,
        environment: BatchExecutionEnvironment
    ) async -> String? {
        guard let cached = environment.preparedVideoSources[source.sourceID] else {
            return await validateVideoSourceOutputSettings(source.sourceURL)
        }

        if let message = videoFFmpegRequirementMessage() {
            return message
        }

        return validateCachedOutputFormatAvailability(
            capabilities: cached.sourceCapabilities,
            selectedFormatNormalizedID: selectedOutputFormatNormalizedID(
                using: Self.videoOutputFormatDescriptor
            ),
            unavailableMessage: "Selected container is not available for this source.",
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID }
        )
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
        outputSettingsValidationMessage(
            for: .image,
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

    func audioHintMessage() -> String? {
        compatibilityHintMessage(for: .audio)
    }

    func audioValidationMessage() -> String? {
        outputSettingsValidationMessage(
            for: .audio,
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

    func validationMessage(for kind: MediaKind) -> String? {
        kind.validationMessage(in: self)
    }

    func hintMessage(for kind: MediaKind) -> String? {
        kind.hintMessage(in: self)
    }

    func validateSourceOutputSettings(for kind: MediaKind, sourceURL: URL) async -> String? {
        await kind.validateSourceOutputSettings(in: self, sourceURL: sourceURL)
    }

    func validatePreparedSourceOutputSettings(
        for kind: MediaKind,
        source: PreparedSourceConversion,
        environment: BatchExecutionEnvironment
    ) async -> String? {
        await kind.validatePreparedSourceOutputSettings(
            in: self,
            source: source,
            environment: environment
        )
    }

    func outputSettingsValidationMessage<Format>(
        for kind: MediaKind,
        formatDescriptor: OutputFormatDescriptor<Format>,
        unavailableMessage: String,
        additionalValidation: () -> String? = { nil }
    ) -> String? {
        let descriptor = kind.mediaStateDescriptor

        if let compatibilityError = nonEmptyMessage(
            self[keyPath: descriptor.compatibilityErrorMessage]
        ) {
            return compatibilityError
        }

        if self[keyPath: descriptor.sourceURL] != nil &&
            !isSelectedOutputFormatAvailable(using: formatDescriptor) {
            return unavailableMessage
        }

        return additionalValidation()
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

extension ContentViewModel.MediaKind {
    func validationMessage(in viewModel: ContentViewModel) -> String? {
        switch self {
        case .video:
            viewModel.videoValidationMessage()
        case .image:
            viewModel.imageValidationMessage()
        case .audio:
            viewModel.audioValidationMessage()
        }
    }

    func hintMessage(in viewModel: ContentViewModel) -> String? {
        switch self {
        case .video:
            nil
        case .image:
            viewModel.imageHintMessage()
        case .audio:
            viewModel.audioHintMessage()
        }
    }

    func validateSourceOutputSettings(
        in viewModel: ContentViewModel,
        sourceURL: URL
    ) async -> String? {
        switch self {
        case .video:
            await viewModel.validateVideoSourceOutputSettings(sourceURL)
        case .image:
            await viewModel.validateImageSourceOutputSettings(sourceURL)
        case .audio:
            await viewModel.validateAudioSourceOutputSettings(sourceURL)
        }
    }

    func validatePreparedSourceOutputSettings(
        in viewModel: ContentViewModel,
        source: PreparedSourceConversion,
        environment: ContentViewModel.BatchExecutionEnvironment
    ) async -> String? {
        switch self {
        case .video:
            await viewModel.validatePreparedVideoSourceOutputSettings(
                source: source,
                environment: environment
            )
        case .image:
            await viewModel.validatePreparedImageSourceOutputSettings(
                source: source,
                environment: environment
            )
        case .audio:
            await viewModel.validatePreparedAudioSourceOutputSettings(
                source: source,
                environment: environment
            )
        }
    }
}
