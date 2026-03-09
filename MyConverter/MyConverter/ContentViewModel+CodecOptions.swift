import Foundation

extension ContentViewModel {
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
            if let preferredEncoder = preferredOptionIfNeeded(
                current: state.selectedOutputEncoder,
                options: resolvedEncoderOptions,
                preferredOption: { ContentViewModelSupport.preferredAudioOutputEncoder(for: format, from: $0) }
            ) {
                state.selectedOutputEncoder = preferredEncoder
            }

            if !state.selectedOutputEncoder.supportsAudioBitRate {
                state.selectedOutputBitRate = .auto
            }
        }
    }

    func normalizeVideoOptionDependencies() {
        let format = selectedOutputFormat
        updateState(\.videoOptionsState) { state in
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
    }

    func normalizeAudioOptionDependencies() {
        let encoderOptions = audioOutputEncoderOptions
        updateState(\.audioOptionsState) { state in
            if let preferredEncoder = preferredOptionIfNeeded(
                current: state.selectedOutputEncoder,
                options: encoderOptions,
                preferredOption: preferredAudioOutputEncoderOption(from:)
            ) {
                state.selectedOutputEncoder = preferredEncoder
            }

            if !state.selectedOutputEncoder.supportsAudioBitRate {
                state.selectedOutputBitRate = .auto
            }
        }
    }
}
