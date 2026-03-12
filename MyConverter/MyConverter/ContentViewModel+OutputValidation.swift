import Foundation

extension ContentViewModel {
    enum PreparedSourceOutputValidationResult {
        case handled(String?)
        case unavailable
    }

    struct MediaValidationDescriptor {
        let validationMessage: (ContentViewModel) -> String?
        let hintMessage: (ContentViewModel) -> String?
        let validateSourceOutputSettings: (ContentViewModel, URL) async -> String?
        let validatePreparedSourceOutputSettings: (
            ContentViewModel,
            PreparedSourceConversion,
            BatchExecutionEnvironment
        ) async -> String?
    }

    private struct OutputFormatValidationInput<Capability, Format> {
        let kind: MediaKind
        let hintMessage: (ContentViewModel) -> String?
        let formatDescriptor: (ContentViewModel) -> OutputFormatDescriptor<Format>
        let unavailableMessage: String
        let preValidation: (ContentViewModel) -> String?
        let additionalValidation: (ContentViewModel) -> String?
        let fetchCapabilities: (URL) async -> Capability
        let availableFormats: (Capability) -> [Format]
        let errorMessage: (Capability) -> String?
        let preSourceValidation: (ContentViewModel, URL) async -> String?
        let additionalCapabilityValidation: (ContentViewModel, Capability) -> String?
        let validatePreparedSource: (
            ContentViewModel,
            PreparedSourceConversion,
            BatchExecutionEnvironment,
            OutputFormatDescriptor<Format>
        ) -> PreparedSourceOutputValidationResult
    }

    func makeMediaValidationDescriptor(
        validationMessage: @escaping (ContentViewModel) -> String?,
        hintMessage: @escaping (ContentViewModel) -> String? = { _ in nil },
        validateSourceOutputSettings: @escaping (ContentViewModel, URL) async -> String?,
        validatePreparedSourceOutputSettings: @escaping (
            ContentViewModel,
            PreparedSourceConversion,
            BatchExecutionEnvironment
        ) async -> String?
    ) -> MediaValidationDescriptor {
        MediaValidationDescriptor(
            validationMessage: validationMessage,
            hintMessage: hintMessage,
            validateSourceOutputSettings: validateSourceOutputSettings,
            validatePreparedSourceOutputSettings: validatePreparedSourceOutputSettings
        )
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
        let descriptor = mediaStateDescriptor(for: kind)
        return nonEmptyMessage(mediaStateValue(using: descriptor, \.compatibilityWarningMessage))
    }

    func videoFFmpegRequirementMessage() -> String? {
        guard requiresFFmpegForCurrentVideoSettings,
              !VideoConversionEngine.isFFmpegAvailable() else {
            return nil
        }

        return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
    }

    func customVideoBitRateValidationMessage() -> String? {
        guard shouldShowVideoBitRateOption,
              selectedVideoBitRate == .custom,
              normalizedCustomVideoBitRateKbps == nil else {
            return nil
        }

        return "Please enter an integer greater than 1 for Custom Bitrate (Kbps)."
    }

    func imageAnimationExportValidationMessage(isAnimated: Bool) -> String? {
        guard isAnimated,
              preserveImageAnimation,
              selectedImageOutputFormat.supportsAnimation,
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

    private func makeOutputFormatValidationDescriptor<Capability, Format>(
        _ input: OutputFormatValidationInput<Capability, Format>
    ) -> MediaValidationDescriptor {
        makeMediaValidationDescriptor(
            validationMessage: { viewModel in
                if let message = input.preValidation(viewModel) {
                    return message
                }

                return viewModel.outputSettingsValidationMessage(
                    for: input.kind,
                    formatDescriptor: input.formatDescriptor(viewModel),
                    unavailableMessage: input.unavailableMessage
                ) {
                    input.additionalValidation(viewModel)
                }
            },
            hintMessage: input.hintMessage,
            validateSourceOutputSettings: { viewModel, sourceURL in
                if let message = await input.preSourceValidation(viewModel, sourceURL) {
                    return message
                }

                let descriptor = input.formatDescriptor(viewModel)
                return await viewModel.validateOutputFormatAvailability(
                    for: sourceURL,
                    selectedFormatNormalizedID: viewModel.selectedOutputFormatNormalizedID(using: descriptor),
                    unavailableMessage: input.unavailableMessage,
                    fetchCapabilities: input.fetchCapabilities,
                    availableFormats: input.availableFormats,
                    errorMessage: input.errorMessage,
                    formatNormalizedID: descriptor.formatNormalizedID,
                    additionalValidation: { capabilities in
                        input.additionalCapabilityValidation(viewModel, capabilities)
                    }
                )
            },
            validatePreparedSourceOutputSettings: { viewModel, source, environment in
                let descriptor = input.formatDescriptor(viewModel)
                switch input.validatePreparedSource(viewModel, source, environment, descriptor) {
                case .handled(let message):
                    return message
                case .unavailable:
                    return await viewModel.validateOutputFormatAvailability(
                        for: source.sourceURL,
                        selectedFormatNormalizedID: viewModel.selectedOutputFormatNormalizedID(using: descriptor),
                        unavailableMessage: input.unavailableMessage,
                        fetchCapabilities: input.fetchCapabilities,
                        availableFormats: input.availableFormats,
                        errorMessage: input.errorMessage,
                        formatNormalizedID: descriptor.formatNormalizedID,
                        additionalValidation: { capabilities in
                            input.additionalCapabilityValidation(viewModel, capabilities)
                        }
                    )
                }
            }
        )
    }

    func videoValidationDescriptor() -> MediaValidationDescriptor {
        makeOutputFormatValidationDescriptor(
            OutputFormatValidationInput(
                kind: .video,
                hintMessage: { _ in nil },
                formatDescriptor: { $0.videoOutputFormatDescriptor() },
                unavailableMessage: "Selected container is not available for this source.",
                preValidation: { viewModel in
                    viewModel.firstNonEmptyMessage(
                        viewModel.sourceURL != nil ? viewModel.videoFFmpegRequirementMessage() : nil,
                        viewModel.customVideoBitRateValidationMessage()
                    )
                },
                additionalValidation: { viewModel in
                    viewModel.firstNonEmptyMessage(
                        viewModel.unavailableSelectedOptionMessage(
                            viewModel.selectedVideoEncoder,
                            in: viewModel.videoEncoderOptions,
                            named: "video encoder"
                        ),
                        viewModel.shouldShowAudioSettings
                            ? viewModel.unavailableSelectedOptionMessage(
                                viewModel.selectedAudioEncoder,
                                in: viewModel.audioEncoderOptions,
                                named: "audio encoder"
                            )
                            : nil
                    )
                },
                fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                errorMessage: { $0.errorMessage },
                preSourceValidation: { viewModel, _ in
                    viewModel.videoFFmpegRequirementMessage()
                },
                additionalCapabilityValidation: { _, _ in nil },
                validatePreparedSource: { viewModel, source, environment, descriptor in
                    guard let cached = environment.preparedVideoSources[source.sourceID] else {
                        return .unavailable
                    }

                    if let message = viewModel.videoFFmpegRequirementMessage() {
                        return .handled(message)
                    }

                    return .handled(
                        viewModel.validateCachedOutputFormatAvailability(
                            capabilities: cached.sourceCapabilities,
                            selectedFormatNormalizedID: viewModel.selectedOutputFormatNormalizedID(
                                using: descriptor
                            ),
                            unavailableMessage: "Selected container is not available for this source.",
                            availableFormats: { $0.availableOutputFormats },
                            errorMessage: { $0.errorMessage },
                            formatNormalizedID: { $0.normalizedID }
                        )
                    )
                }
            )
        )
    }

    func imageValidationDescriptor() -> MediaValidationDescriptor {
        makeOutputFormatValidationDescriptor(
            OutputFormatValidationInput(
                kind: .image,
                hintMessage: { viewModel in
                    viewModel.firstNonEmptyMessage(
                        viewModel.imageSourceIsAnimated && !viewModel.selectedImageOutputFormat.supportsAnimation
                            ? "This format exports only the first frame for animated sources."
                            : nil,
                        viewModel.shouldShowPreserveAnimationOption && !ImageConversionEngine.isFFmpegAvailable()
                            ? "ffmpeg is required to preserve animation."
                            : nil
                    )
                },
                formatDescriptor: { $0.imageOutputFormatDescriptor() },
                unavailableMessage: "Selected output format is not available for this source.",
                preValidation: { _ in nil },
                additionalValidation: { viewModel in
                    viewModel.imageAnimationExportValidationMessage(
                        isAnimated: viewModel.imageSourceIsAnimated
                    )
                },
                fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                errorMessage: { $0.errorMessage },
                preSourceValidation: { _, _ in nil },
                additionalCapabilityValidation: { viewModel, capabilities in
                    viewModel.imageAnimationExportValidationMessage(
                        isAnimated: capabilities.frameCount > 1
                    )
                },
                validatePreparedSource: { viewModel, source, environment, descriptor in
                    guard let cached = environment.preparedImageCapabilities[source.sourceID] else {
                        return .unavailable
                    }

                    return .handled(
                        viewModel.validateCachedOutputFormatAvailability(
                            capabilities: cached,
                            selectedFormatNormalizedID: viewModel.selectedOutputFormatNormalizedID(
                                using: descriptor
                            ),
                            unavailableMessage: "Selected output format is not available for this source.",
                            availableFormats: { $0.availableOutputFormats },
                            errorMessage: { $0.errorMessage },
                            formatNormalizedID: { $0.normalizedID },
                            additionalValidation: { capabilities in
                                viewModel.imageAnimationExportValidationMessage(
                                    isAnimated: capabilities.frameCount > 1
                                )
                            }
                        )
                    )
                }
            )
        )
    }

    func audioValidationDescriptor() -> MediaValidationDescriptor {
        makeOutputFormatValidationDescriptor(
            OutputFormatValidationInput(
                kind: .audio,
                hintMessage: { viewModel in
                    viewModel.compatibilityHintMessage(for: .audio)
                },
                formatDescriptor: { $0.audioOutputFormatDescriptor() },
                unavailableMessage: "Selected output format is not available for this source.",
                preValidation: { _ in nil },
                additionalValidation: { viewModel in
                    viewModel.unavailableSelectedOptionMessage(
                        viewModel.selectedAudioOutputEncoder,
                        in: viewModel.audioOutputEncoderOptions,
                        named: "audio encoder"
                    )
                },
                fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
                availableFormats: { $0.availableOutputFormats },
                errorMessage: { $0.errorMessage },
                preSourceValidation: { _, _ in nil },
                additionalCapabilityValidation: { _, _ in nil },
                validatePreparedSource: { viewModel, source, environment, descriptor in
                    guard let cached = environment.preparedAudioCapabilities[source.sourceID] else {
                        return .unavailable
                    }

                    return .handled(
                        viewModel.validateCachedOutputFormatAvailability(
                            capabilities: cached,
                            selectedFormatNormalizedID: viewModel.selectedOutputFormatNormalizedID(
                                using: descriptor
                            ),
                            unavailableMessage: "Selected output format is not available for this source.",
                            availableFormats: { $0.availableOutputFormats },
                            errorMessage: { $0.errorMessage },
                            formatNormalizedID: { $0.normalizedID }
                        )
                    )
                }
            )
        )
    }

    func mediaValidationDescriptor(for kind: MediaKind) -> MediaValidationDescriptor {
        mediaBehaviorDescriptor(for: kind).validation
    }

    func validationMessage(for kind: MediaKind) -> String? {
        mediaValidationDescriptor(for: kind).validationMessage(self)
    }

    func hintMessage(for kind: MediaKind) -> String? {
        mediaValidationDescriptor(for: kind).hintMessage(self)
    }

    func validateSourceOutputSettings(for kind: MediaKind, sourceURL: URL) async -> String? {
        await mediaValidationDescriptor(for: kind).validateSourceOutputSettings(self, sourceURL)
    }

    func validatePreparedSourceOutputSettings(
        for kind: MediaKind,
        source: PreparedSourceConversion,
        environment: BatchExecutionEnvironment
    ) async -> String? {
        await mediaValidationDescriptor(for: kind).validatePreparedSourceOutputSettings(
            self,
            source,
            environment
        )
    }

    func outputSettingsValidationMessage<Format>(
        for kind: MediaKind,
        formatDescriptor: OutputFormatDescriptor<Format>,
        unavailableMessage: String,
        additionalValidation: () -> String? = { nil }
    ) -> String? {
        let descriptor = mediaStateDescriptor(for: kind)

        if let compatibilityError = nonEmptyMessage(
            mediaStateValue(using: descriptor, \.compatibilityErrorMessage)
        ) {
            return compatibilityError
        }

        if mediaStateValue(using: descriptor, \.sourceURL) != nil &&
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
