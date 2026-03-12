import Foundation

extension ContentViewModel {
    private func normalizeVideoCodecDependencies(
        in state: inout VideoOptionsState,
        format: VideoFormatOption
    ) {
        if !state.selectedVideoEncoder.supportsVideoBitRate {
            state.selectedVideoBitRate = .auto
        }

        guard format.supportsAudioTrack else {
            state.selectedAudioEncoder = .auto
            state.selectedAudioMode = .auto
            state.selectedAudioBitRate = .auto
            return
        }

        if !state.selectedAudioEncoder.supportsAudioBitRate {
            state.selectedAudioBitRate = .auto
        }
    }

    private func normalizeAudioCodecDependencies(
        in state: inout AudioOptionsState,
        encoderOptions: [AudioEncoderOption],
        preferredOption: ([AudioEncoderOption]) -> AudioEncoderOption?
    ) {
        if let preferredEncoder = preferredOptionIfNeeded(
            current: state.selectedOutputEncoder,
            options: encoderOptions,
            preferredOption: preferredOption
        ) {
            state.selectedOutputEncoder = preferredEncoder
        }

        if !state.selectedOutputEncoder.supportsAudioBitRate {
            state.selectedOutputBitRate = .auto
        }
    }

    private func preferredAudioOutputEncoderOption(
        from options: [AudioEncoderOption]
    ) -> AudioEncoderOption? {
        ContentViewModelSupport.preferredAudioOutputEncoder(
            for: selectedAudioOutputFormat,
            from: options
        )
    }

    private func preferredOptionIfNeeded<Option: Equatable>(
        current selection: Option,
        options: [Option],
        preferredOption: ([Option]) -> Option?
    ) -> Option? {
        guard !options.contains(selection) else { return selection }
        return preferredOption(options)
    }

    func refreshVideoCodecOptions() {
        let format = selectedOutputFormat
        let resolvedVideoEncoders = VideoConversionEngine.availableVideoEncoders(for: format)
        let resolvedAudioEncoders = format.supportsAudioTrack
            ? VideoConversionEngine.availableAudioEncoders(for: format)
            : []
        let resolvedVideoEncoderOptions = resolvedOptions(resolvedVideoEncoders) {
            format.avFileType == nil ? [] : [.auto]
        }
        let resolvedAudioEncoderOptions = format.supportsAudioTrack
            ? resolvedOptions(resolvedAudioEncoders) {
                format.avFileType == nil ? [] : [.auto]
            }
            : []

        updateState(\.videoRuntimeState) { state in
            state.availableVideoEncoders = resolvedVideoEncoders
            state.availableAudioEncoders = resolvedAudioEncoders
        }

        updateState(\.videoOptionsState) { state in
            if let preferredVideoEncoder = preferredOptionIfNeeded(
                current: state.selectedVideoEncoder,
                options: resolvedVideoEncoderOptions,
                preferredOption: ContentViewModelSupport.preferredVideoEncoder(from:)
            ) {
                state.selectedVideoEncoder = preferredVideoEncoder
            }

            if format.supportsAudioTrack,
               let preferredAudioEncoder = preferredOptionIfNeeded(
                   current: state.selectedAudioEncoder,
                   options: resolvedAudioEncoderOptions,
                   preferredOption: ContentViewModelSupport.preferredAudioEncoder(from:)
               ) {
                state.selectedAudioEncoder = preferredAudioEncoder
            }
            normalizeVideoCodecDependencies(in: &state, format: format)
        }
    }

    func applyPlaceholderVideoCodecOptions() {
        let format = selectedOutputFormat
        updateState(\.videoRuntimeState) { state in
            state.availableVideoEncoders = ContentViewModelSupport.placeholderVideoEncoders(for: format)
            state.availableAudioEncoders = ContentViewModelSupport.placeholderVideoAudioEncoders(for: format)
        }
        normalizeVideoOptionDependencies()
    }

    func refreshAudioCodecOptions() {
        let format = selectedAudioOutputFormat
        let resolvedEncoders = VideoConversionEngine.availableAudioEncoders(for: format)
        let resolvedEncoderOptions = resolvedOptions(resolvedEncoders) {
            if audioSourceURL == nil && format.allowsFFmpegAutomaticAudioCodec {
                return [.auto]
            }
            return []
        }

        updateState(\.audioRuntimeState) { state in
            state.availableOutputEncoders = resolvedEncoders
        }

        updateState(\.audioOptionsState) { state in
            normalizeAudioCodecDependencies(
                in: &state,
                encoderOptions: resolvedEncoderOptions,
                preferredOption: { ContentViewModelSupport.preferredAudioOutputEncoder(for: format, from: $0) }
            )
        }
    }

    func applyPlaceholderAudioCodecOptions() {
        let format = selectedAudioOutputFormat
        updateState(\.audioRuntimeState) { state in
            state.availableOutputEncoders = ContentViewModelSupport.placeholderAudioOutputEncoders(
                for: format
            )
        }
        normalizeAudioOptionDependencies()
    }

    func normalizeVideoOptionDependencies() {
        let format = selectedOutputFormat
        updateState(\.videoOptionsState) { state in
            normalizeVideoCodecDependencies(in: &state, format: format)
        }
    }

    func normalizeAudioOptionDependencies() {
        let encoderOptions = audioOutputEncoderOptions
        updateState(\.audioOptionsState) { state in
            normalizeAudioCodecDependencies(
                in: &state,
                encoderOptions: encoderOptions,
                preferredOption: preferredAudioOutputEncoderOption(from:)
            )
        }
    }
}
