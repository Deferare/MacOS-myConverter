import Foundation

extension ContentViewModel {
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

    private func preferredOptionIfNeeded<Option: Equatable>(
        current selection: Option,
        options: [Option],
        preferredOption: ([Option]) -> Option?
    ) -> Option? {
        guard !options.contains(selection) else { return selection }
        return preferredOption(options)
    }

    private func resolvedAudioEncoderOptions(
        _ availableEncoders: [AudioEncoderOption],
        includesAutoOption: Bool
    ) -> [AudioEncoderOption] {
        resolvedOptions(
            availableEncoders,
            autoOption: .auto,
            includesAutoOption: includesAutoOption
        )
    }

    private func videoAudioEncoderOptions(
        for format: VideoFormatOption,
        availableEncoders: [AudioEncoderOption]
    ) -> [AudioEncoderOption] {
        guard format.supportsAudioTrack else { return [] }
        return resolvedAudioEncoderOptions(
            availableEncoders,
            includesAutoOption: format.avFileType != nil
        )
    }

    private func audioOutputEncoderOptions(
        for format: AudioFormatOption,
        availableEncoders: [AudioEncoderOption]
    ) -> [AudioEncoderOption] {
        resolvedAudioEncoderOptions(
            availableEncoders,
            includesAutoOption: audioRuntimeState.media.sourceURL == nil
                && format.allowsFFmpegAutomaticAudioCodec
        )
    }

    private func normalizeVideoAudioDependencies(
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

    private func normalizeAudioOutputDependencies(
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

    private func applyVideoAudioDependencies(
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

    private func applyAudioOutputDependencies(
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

    private func resetVideoBitRateIfNeeded(in state: inout VideoOptionsState) {
        guard !state.selectedVideoEncoder.supportsVideoBitRate else { return }
        state.selectedVideoBitRate = .auto
    }

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

extension ContentViewModel.MediaKind {
    private struct CodecBehavior {
        let refreshCodecOptions: (ContentViewModel) -> Void
        let applyPlaceholderCodecOptions: (ContentViewModel) -> Void
        let normalizeOptionDependencies: (ContentViewModel) -> Void
    }

    private static let codecBehaviorByKind: [Self: CodecBehavior] = [
        .video: CodecBehavior(
            refreshCodecOptions: { $0.refreshVideoCodecOptions() },
            applyPlaceholderCodecOptions: { $0.applyPlaceholderVideoCodecOptions() },
            normalizeOptionDependencies: { $0.normalizeVideoOptionDependencies() }
        ),
        .image: CodecBehavior(
            refreshCodecOptions: { _ in },
            applyPlaceholderCodecOptions: { _ in },
            normalizeOptionDependencies: { _ in }
        ),
        .audio: CodecBehavior(
            refreshCodecOptions: { $0.refreshAudioCodecOptions() },
            applyPlaceholderCodecOptions: { $0.applyPlaceholderAudioCodecOptions() },
            normalizeOptionDependencies: { $0.normalizeAudioOptionDependencies() }
        )
    ]

    private var codecBehavior: CodecBehavior {
        Self.codecBehaviorByKind[self] ?? Self.codecBehaviorByKind[.video]!
    }

    func refreshCodecOptions(in viewModel: ContentViewModel) {
        codecBehavior.refreshCodecOptions(viewModel)
    }

    func applyPlaceholderCodecOptions(to viewModel: ContentViewModel) {
        codecBehavior.applyPlaceholderCodecOptions(viewModel)
    }

    func normalizeOptionDependencies(in viewModel: ContentViewModel) {
        codecBehavior.normalizeOptionDependencies(viewModel)
    }
}
