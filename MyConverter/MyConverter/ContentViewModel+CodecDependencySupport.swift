import Foundation

extension ContentViewModel {
    func applyPreferredOptionIfNeeded<State, Option: Equatable>(
        in state: inout State,
        selection: WritableKeyPath<State, Option>,
        options: [Option],
        preferredOption: ([Option]) -> Option?
    ) {
        if let preferredSelection = preferredOptionIfNeeded(
            current: state[keyPath: selection],
            options: options,
            preferredOption: preferredOption
        ) {
            state[keyPath: selection] = preferredSelection
        }
    }

    func preferredOptionIfNeeded<Option: Equatable>(
        current selection: Option,
        options: [Option],
        preferredOption: ([Option]) -> Option?
    ) -> Option? {
        guard !options.contains(selection) else { return selection }
        return preferredOption(options)
    }

    func resolvedAudioEncoderOptions(
        _ availableEncoders: [AudioEncoderOption],
        includesAutoOption: Bool
    ) -> [AudioEncoderOption] {
        resolvedOptions(
            availableEncoders,
            autoOption: .auto,
            includesAutoOption: includesAutoOption
        )
    }

    func videoAudioEncoderOptions(
        for format: VideoFormatOption,
        availableEncoders: [AudioEncoderOption]
    ) -> [AudioEncoderOption] {
        guard format.supportsAudioTrack else { return [] }
        return resolvedAudioEncoderOptions(
            availableEncoders,
            includesAutoOption: format.avFileType != nil
        )
    }

    func audioOutputEncoderOptions(
        for format: AudioFormatOption,
        availableEncoders: [AudioEncoderOption]
    ) -> [AudioEncoderOption] {
        resolvedAudioEncoderOptions(
            availableEncoders,
            includesAutoOption: audioRuntimeState.media.sourceURL == nil
                && format.allowsFFmpegAutomaticAudioCodec
        )
    }

    func normalizeVideoAudioDependencies(
        in state: inout VideoOptionsState,
        format: VideoFormatOption,
        encoderOptions: [AudioEncoderOption]
    ) {
        guard format.supportsAudioTrack else {
            state.selectedAudioEncoder = .auto
            state.selectedAudioMode = .auto
            state.selectedAudioBitRate = .auto
            return
        }

        applyPreferredOptionIfNeeded(
            in: &state,
            selection: \.selectedAudioEncoder,
            options: encoderOptions,
            preferredOption: ContentViewModelSupport.preferredAudioEncoder(from:)
        )
        if !state.selectedAudioEncoder.supportsAudioBitRate {
            state.selectedAudioBitRate = .auto
        }
    }

    func normalizeAudioOutputDependencies(
        in state: inout AudioOptionsState,
        format: AudioFormatOption,
        encoderOptions: [AudioEncoderOption]
    ) {
        applyPreferredOptionIfNeeded(
            in: &state,
            selection: \.selectedOutputEncoder,
            options: encoderOptions,
            preferredOption: { options in
                ContentViewModelSupport.preferredAudioOutputEncoder(for: format, from: options)
            }
        )
        if !state.selectedOutputEncoder.supportsAudioBitRate {
            state.selectedOutputBitRate = .auto
        }
    }

    func applyVideoAudioDependencies(
        availableEncoders: [AudioEncoderOption]
    ) {
        let format = videoOptionsState.selectedOutputFormat
        let encoderOptions = videoAudioEncoderOptions(
            for: format,
            availableEncoders: availableEncoders
        )

        videoRuntimeState.availableAudioEncoders = availableEncoders
        updateState(\.videoOptionsState) { state in
            normalizeVideoAudioDependencies(
                in: &state,
                format: format,
                encoderOptions: encoderOptions
            )
        }
    }

    func applyAudioOutputDependencies(
        availableEncoders: [AudioEncoderOption]
    ) {
        let format = audioOptionsState.selectedOutputFormat
        let encoderOptions = audioOutputEncoderOptions(
            for: format,
            availableEncoders: availableEncoders
        )

        audioRuntimeState.availableOutputEncoders = availableEncoders
        updateState(\.audioOptionsState) { state in
            normalizeAudioOutputDependencies(
                in: &state,
                format: format,
                encoderOptions: encoderOptions
            )
        }
    }

    func resetVideoBitRateIfNeeded(in state: inout VideoOptionsState) {
        guard !state.selectedVideoEncoder.supportsVideoBitRate else { return }
        state.selectedVideoBitRate = .auto
    }
}
