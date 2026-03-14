import Foundation

extension ContentViewModel {
    var videoAudioEncoderSelectionOptions: [AudioEncoderOption] {
        videoAudioEncoderOptions(
            for: videoOptionsState.selectedOutputFormat,
            availableEncoders: videoRuntimeState.availableAudioEncoders
        )
    }

    var audioOutputEncoderSelectionOptions: [AudioEncoderOption] {
        audioOutputEncoderOptions(
            for: audioOptionsState.selectedOutputFormat,
            availableEncoders: audioRuntimeState.availableOutputEncoders
        )
    }

    func refreshVideoCodecOptions() {
        let format = videoOptionsState.selectedOutputFormat
        let resolvedVideoEncoders = VideoConversionEngine.availableVideoEncoders(for: format)
        let resolvedAudioEncoders = VideoConversionEngine.availableAudioEncoders(for: format)
        let resolvedVideoEncoderOptions = resolvedOptions(
            resolvedVideoEncoders,
            autoOption: VideoEncoderOption.auto,
            includesAutoOption: format.avFileType != nil
        )
        let resolvedAudioEncoderOptions = videoAudioEncoderOptions(
            for: format,
            availableEncoders: resolvedAudioEncoders
        )

        videoRuntimeState.availableVideoEncoders = resolvedVideoEncoders
        videoRuntimeState.availableAudioEncoders = resolvedAudioEncoders

        updateState(\.videoOptionsState) { state in
            applyPreferredOptionIfNeeded(
                in: &state,
                selection: \.selectedVideoEncoder,
                options: resolvedVideoEncoderOptions,
                preferredOption: ContentViewModelSupport.preferredVideoEncoder(from:)
            )

            if format.supportsAudioTrack {
                applyPreferredOptionIfNeeded(
                    in: &state,
                    selection: \.selectedAudioEncoder,
                    options: resolvedAudioEncoderOptions,
                    preferredOption: ContentViewModelSupport.preferredAudioEncoder(from:)
                )
            }
            normalizeVideoAudioDependencies(
                in: &state,
                format: format,
                encoderOptions: resolvedAudioEncoderOptions
            )
            resetVideoBitRateIfNeeded(in: &state)
        }
    }

    func applyPlaceholderVideoCodecOptions() {
        let format = videoOptionsState.selectedOutputFormat
        videoRuntimeState.availableVideoEncoders = ContentViewModelSupport.placeholderVideoEncoders(for: format)
        applyVideoAudioDependencies(
            availableEncoders: ContentViewModelSupport.placeholderVideoAudioEncoders(for: format)
        )
        updateState(\.videoOptionsState) { state in
            resetVideoBitRateIfNeeded(in: &state)
        }
    }

    func refreshAudioCodecOptions() {
        applyAudioOutputDependencies(
            availableEncoders: VideoConversionEngine.availableAudioEncoders(
                for: audioOptionsState.selectedOutputFormat
            )
        )
    }

    func applyPlaceholderAudioCodecOptions() {
        applyAudioOutputDependencies(
            availableEncoders: ContentViewModelSupport.placeholderAudioOutputEncoders(
                for: audioOptionsState.selectedOutputFormat
            )
        )
    }

    func normalizeVideoOptionDependencies() {
        let format = videoOptionsState.selectedOutputFormat
        let encoderOptions = videoAudioEncoderOptions(
            for: format,
            availableEncoders: videoRuntimeState.availableAudioEncoders
        )
        updateState(\.videoOptionsState) { state in
            normalizeVideoAudioDependencies(
                in: &state,
                format: format,
                encoderOptions: encoderOptions
            )
            resetVideoBitRateIfNeeded(in: &state)
        }
    }

    func normalizeAudioOptionDependencies() {
        let format = audioOptionsState.selectedOutputFormat
        let encoderOptions = audioOutputEncoderOptions(
            for: format,
            availableEncoders: audioRuntimeState.availableOutputEncoders
        )
        updateState(\.audioOptionsState) { state in
            normalizeAudioOutputDependencies(
                in: &state,
                format: format,
                encoderOptions: encoderOptions
            )
        }
    }
}
