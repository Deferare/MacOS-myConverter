import Foundation

extension ContentViewModel {
    private func setDefaultValueIfNeeded<Value: Equatable>(
        _ value: inout Value,
        when condition: Bool,
        defaultValue: Value
    ) {
        guard condition else { return }
        value = defaultValue
    }

    private func applyPreferredOptionIfNeeded<State, Option: Equatable>(
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

    private func normalizeVideoCodecDependencies(
        in state: inout VideoOptionsState,
        format: VideoFormatOption
    ) {
        setDefaultValueIfNeeded(
            &state.selectedVideoBitRate,
            when: !state.selectedVideoEncoder.supportsVideoBitRate,
            defaultValue: .auto
        )

        guard format.supportsAudioTrack else {
            state.selectedAudioEncoder = .auto
            state.selectedAudioMode = .auto
            state.selectedAudioBitRate = .auto
            return
        }

        setDefaultValueIfNeeded(
            &state.selectedAudioBitRate,
            when: !state.selectedAudioEncoder.supportsAudioBitRate,
            defaultValue: .auto
        )
    }

    private func normalizeAudioCodecDependencies(
        in state: inout AudioOptionsState,
        encoderOptions: [AudioEncoderOption],
        preferredOption: ([AudioEncoderOption]) -> AudioEncoderOption?
    ) {
        applyPreferredOptionIfNeeded(
            in: &state,
            selection: \.selectedOutputEncoder,
            options: encoderOptions,
            preferredOption: preferredOption
        )
        setDefaultValueIfNeeded(
            &state.selectedOutputBitRate,
            when: !state.selectedOutputEncoder.supportsAudioBitRate,
            defaultValue: .auto
        )
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
        let resolvedVideoEncoderOptions = resolvedOptions(
            resolvedVideoEncoders,
            autoOption: VideoEncoderOption.auto,
            includesAutoOption: format.avFileType != nil
        )
        let resolvedAudioEncoderOptions = format.supportsAudioTrack
            ? resolvedOptions(
                resolvedAudioEncoders,
                autoOption: AudioEncoderOption.auto,
                includesAutoOption: format.avFileType != nil
            )
            : []

        availableVideoEncoders = resolvedVideoEncoders
        availableAudioEncoders = resolvedAudioEncoders

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
            normalizeVideoCodecDependencies(in: &state, format: format)
        }
    }

    func applyPlaceholderVideoCodecOptions() {
        let format = selectedOutputFormat
        availableVideoEncoders = ContentViewModelSupport.placeholderVideoEncoders(for: format)
        availableAudioEncoders = ContentViewModelSupport.placeholderVideoAudioEncoders(for: format)
        normalizeVideoOptionDependencies()
    }

    func refreshAudioCodecOptions() {
        let format = selectedAudioOutputFormat
        let resolvedEncoders = VideoConversionEngine.availableAudioEncoders(for: format)
        let resolvedEncoderOptions = resolvedOptions(
            resolvedEncoders,
            autoOption: AudioEncoderOption.auto,
            includesAutoOption: audioSourceURL == nil && format.allowsFFmpegAutomaticAudioCodec
        )

        availableAudioOutputEncoders = resolvedEncoders

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
        availableAudioOutputEncoders = ContentViewModelSupport.placeholderAudioOutputEncoders(
            for: format
        )
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
