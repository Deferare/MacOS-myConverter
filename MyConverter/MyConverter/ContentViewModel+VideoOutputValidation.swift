import Foundation

extension ContentViewModel {
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

    func videoValidationMessage() -> String? {
        firstNonEmptyMessage(
            videoRuntimeState.media.sourceURL != nil ? videoFFmpegRequirementMessage() : nil,
            customVideoBitRateValidationMessage()
        ) ?? MediaKind.video.outputSettingsValidationMessage(
            in: self,
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
}
