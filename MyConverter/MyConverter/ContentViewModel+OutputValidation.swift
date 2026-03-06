import Foundation

extension ContentViewModel {
    struct MediaValidationDescriptor {
        let validationMessage: (ContentViewModel) -> String?
        let hintMessage: (ContentViewModel) -> String?
        let validateSourceOutputSettings: (ContentViewModel, URL) async -> String?
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

    func mediaValidationDescriptor(for kind: MediaKind) -> MediaValidationDescriptor {
        switch kind {
        case .video:
            return MediaValidationDescriptor(
                validationMessage: { viewModel in
                    if viewModel.sourceURL != nil &&
                        viewModel.requiresFFmpegForCurrentVideoSettings &&
                        !VideoConversionEngine.isFFmpegAvailable() {
                        return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
                    }
                    if viewModel.shouldShowVideoBitRateOption &&
                        viewModel.selectedVideoBitRate == .custom &&
                        viewModel.normalizedCustomVideoBitRateKbps == nil {
                        return "Please enter an integer greater than 1 for Custom Bitrate (Kbps)."
                    }
                    return viewModel.outputSettingsValidationMessage(
                        for: .video,
                        formatDescriptor: viewModel.videoOutputFormatDescriptor(),
                        unavailableMessage: "Selected container is not available for this source."
                    ) {
                        if !viewModel.videoEncoderOptions.contains(viewModel.selectedVideoEncoder) {
                            return "Selected video encoder is not available for this format."
                        }
                        if viewModel.shouldShowAudioSettings &&
                            !viewModel.audioEncoderOptions.contains(viewModel.selectedAudioEncoder) {
                            return "Selected audio encoder is not available for this format."
                        }
                        return nil
                    }
                },
                hintMessage: { _ in nil },
                validateSourceOutputSettings: { viewModel, sourceURL in
                    if viewModel.requiresFFmpegForCurrentVideoSettings &&
                        !VideoConversionEngine.isFFmpegAvailable() {
                        return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
                    }

                    return await viewModel.validateSelectedOutputFormatAvailability(
                        for: sourceURL,
                        formatDescriptor: viewModel.videoOutputFormatDescriptor(),
                        unavailableMessage: "Selected container is not available for this source.",
                        fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
                        availableFormats: { $0.availableOutputFormats },
                        errorMessage: { $0.errorMessage }
                    )
                }
            )
        case .image:
            return MediaValidationDescriptor(
                validationMessage: { viewModel in
                    viewModel.outputSettingsValidationMessage(
                        for: .image,
                        formatDescriptor: viewModel.imageOutputFormatDescriptor(),
                        unavailableMessage: "Selected output format is not available for this source."
                    ) {
                        if viewModel.imageSourceIsAnimated &&
                            viewModel.preserveImageAnimation &&
                            viewModel.selectedImageOutputFormat.supportsAnimation &&
                            !ImageConversionEngine.isFFmpegAvailable() {
                            return "Animated output requires ffmpeg for the selected format."
                        }
                        return nil
                    }
                },
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
                validateSourceOutputSettings: { viewModel, sourceURL in
                    await viewModel.validateSelectedOutputFormatAvailability(
                        for: sourceURL,
                        formatDescriptor: viewModel.imageOutputFormatDescriptor(),
                        unavailableMessage: "Selected output format is not available for this source.",
                        fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
                        availableFormats: { $0.availableOutputFormats },
                        errorMessage: { $0.errorMessage },
                        additionalValidation: { capabilities in
                            if capabilities.frameCount > 1 &&
                                viewModel.preserveImageAnimation &&
                                viewModel.selectedImageOutputFormat.supportsAnimation &&
                                !ImageConversionEngine.isFFmpegAvailable() {
                                return "Animated output requires ffmpeg for the selected format."
                            }
                            return nil
                        }
                    )
                }
            )
        case .audio:
            return MediaValidationDescriptor(
                validationMessage: { viewModel in
                    viewModel.outputSettingsValidationMessage(
                        for: .audio,
                        formatDescriptor: viewModel.audioOutputFormatDescriptor(),
                        unavailableMessage: "Selected output format is not available for this source."
                    ) {
                        if !viewModel.audioOutputEncoderOptions.contains(viewModel.selectedAudioOutputEncoder) {
                            return "Selected audio encoder is not available for this format."
                        }
                        return nil
                    }
                },
                hintMessage: { viewModel in
                    viewModel.compatibilityHintMessage(for: .audio)
                },
                validateSourceOutputSettings: { viewModel, sourceURL in
                    await viewModel.validateSelectedOutputFormatAvailability(
                        for: sourceURL,
                        formatDescriptor: viewModel.audioOutputFormatDescriptor(),
                        unavailableMessage: "Selected output format is not available for this source.",
                        fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
                        availableFormats: { $0.availableOutputFormats },
                        errorMessage: { $0.errorMessage }
                    )
                }
            )
        }
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
