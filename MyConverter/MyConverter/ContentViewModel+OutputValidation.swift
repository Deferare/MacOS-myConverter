import Foundation

extension ContentViewModel {
    struct MediaValidationDescriptor {
        let validationMessage: (ContentViewModel) -> String?
        let hintMessage: (ContentViewModel) -> String?
        let validateSourceOutputSettings: (ContentViewModel, URL) async -> String?
    }

    func makeMediaValidationDescriptor(
        validationMessage: @escaping (ContentViewModel) -> String?,
        hintMessage: @escaping (ContentViewModel) -> String? = { _ in nil },
        validateSourceOutputSettings: @escaping (ContentViewModel, URL) async -> String?
    ) -> MediaValidationDescriptor {
        MediaValidationDescriptor(
            validationMessage: validationMessage,
            hintMessage: hintMessage,
            validateSourceOutputSettings: validateSourceOutputSettings
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
        return nonEmptyMessage(self[keyPath: descriptor.compatibilityWarningMessage])
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

    func makeOutputFormatValidationDescriptor<Capability, Format>(
        kind: MediaKind,
        hintMessage: @escaping (ContentViewModel) -> String? = { _ in nil },
        formatDescriptor: @escaping (ContentViewModel) -> OutputFormatDescriptor<Format>,
        unavailableMessage: String,
        preValidation: @escaping (ContentViewModel) -> String? = { _ in nil },
        additionalValidation: @escaping (ContentViewModel) -> String? = { _ in nil },
        fetchCapabilities: @escaping (URL) async -> Capability,
        availableFormats: @escaping (Capability) -> [Format],
        errorMessage: @escaping (Capability) -> String?,
        preSourceValidation: @escaping (ContentViewModel, URL) async -> String? = { _, _ in nil },
        additionalCapabilityValidation: @escaping (ContentViewModel, Capability) -> String? = { _, _ in nil }
    ) -> MediaValidationDescriptor {
        makeMediaValidationDescriptor(
            validationMessage: { viewModel in
                if let message = preValidation(viewModel) {
                    return message
                }

                return viewModel.outputSettingsValidationMessage(
                    for: kind,
                    formatDescriptor: formatDescriptor(viewModel),
                    unavailableMessage: unavailableMessage
                ) {
                    additionalValidation(viewModel)
                }
            },
            hintMessage: hintMessage,
            validateSourceOutputSettings: { viewModel, sourceURL in
                if let message = await preSourceValidation(viewModel, sourceURL) {
                    return message
                }

                return await viewModel.validateSelectedOutputFormatAvailability(
                    for: sourceURL,
                    formatDescriptor: formatDescriptor(viewModel),
                    unavailableMessage: unavailableMessage,
                    fetchCapabilities: fetchCapabilities,
                    availableFormats: availableFormats,
                    errorMessage: errorMessage,
                    additionalValidation: { capabilities in
                        additionalCapabilityValidation(viewModel, capabilities)
                    }
                )
            }
        )
    }

    func videoValidationDescriptor() -> MediaValidationDescriptor {
        makeOutputFormatValidationDescriptor(
            kind: .video,
            formatDescriptor: { $0.videoOutputFormatDescriptor() },
            unavailableMessage: "Selected container is not available for this source.",
            preValidation: { viewModel in
                viewModel.firstNonEmptyMessage(
                    viewModel.sourceURL != nil ? viewModel.videoFFmpegRequirementMessage() : nil,
                    viewModel.customVideoBitRateValidationMessage()
                )
            },
            additionalValidation: { viewModel in
                if !viewModel.videoEncoderOptions.contains(viewModel.selectedVideoEncoder) {
                    return "Selected video encoder is not available for this format."
                }
                if viewModel.shouldShowAudioSettings &&
                    !viewModel.audioEncoderOptions.contains(viewModel.selectedAudioEncoder) {
                    return "Selected audio encoder is not available for this format."
                }
                return nil
            },
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            preSourceValidation: { viewModel, _ in
                viewModel.videoFFmpegRequirementMessage()
            }
        )
    }

    func imageValidationDescriptor() -> MediaValidationDescriptor {
        makeOutputFormatValidationDescriptor(
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
            additionalValidation: { viewModel in
                viewModel.imageAnimationExportValidationMessage(
                    isAnimated: viewModel.imageSourceIsAnimated
                )
            },
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            additionalCapabilityValidation: { viewModel, capabilities in
                viewModel.imageAnimationExportValidationMessage(
                    isAnimated: capabilities.frameCount > 1
                )
            }
        )
    }

    func audioValidationDescriptor() -> MediaValidationDescriptor {
        makeOutputFormatValidationDescriptor(
            kind: .audio,
            hintMessage: { viewModel in
                viewModel.compatibilityHintMessage(for: .audio)
            },
            formatDescriptor: { $0.audioOutputFormatDescriptor() },
            unavailableMessage: "Selected output format is not available for this source.",
            additionalValidation: { viewModel in
                if !viewModel.audioOutputEncoderOptions.contains(viewModel.selectedAudioOutputEncoder) {
                    return "Selected audio encoder is not available for this format."
                }
                return nil
            },
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage }
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
