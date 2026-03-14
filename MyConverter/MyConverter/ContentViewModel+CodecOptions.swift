import Foundation

extension ContentViewModel {
    private struct AudioCodecDependencyDescriptor<State, Format> {
        let stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>
        let currentFormat: (ContentViewModel) -> Format
        let availableEncoders: ReferenceWritableKeyPath<ContentViewModel, [AudioEncoderOption]>
        let encoder: WritableKeyPath<State, AudioEncoderOption>
        let audioMode: WritableKeyPath<State, AudioModeOption>?
        let bitRate: WritableKeyPath<State, AudioBitRateOption>
        let supportsAudioTrack: (Format) -> Bool
        let includesAutoOption: (ContentViewModel, Format) -> Bool
        let resolvedEncoders: (Format) -> [AudioEncoderOption]
        let placeholderEncoders: (Format) -> [AudioEncoderOption]
        let preferredEncoder: (Format, [AudioEncoderOption]) -> AudioEncoderOption?
    }

    private static let videoAudioCodecDependencyDescriptor = AudioCodecDependencyDescriptor<
        VideoOptionsState,
        VideoFormatOption
    >(
        stateKeyPath: \.videoOptionsState,
        currentFormat: { $0.videoOptionsState.selectedOutputFormat },
        availableEncoders: \.videoRuntimeState.availableAudioEncoders,
        encoder: \.selectedAudioEncoder,
        audioMode: \.selectedAudioMode,
        bitRate: \.selectedAudioBitRate,
        supportsAudioTrack: { $0.supportsAudioTrack },
        includesAutoOption: { _, format in
            format.avFileType != nil
        },
        resolvedEncoders: { format in
            VideoConversionEngine.availableAudioEncoders(for: format)
        },
        placeholderEncoders: { format in
            ContentViewModelSupport.placeholderVideoAudioEncoders(for: format)
        },
        preferredEncoder: { _, options in
            ContentViewModelSupport.preferredAudioEncoder(from: options)
        }
    )

    private static let audioOutputCodecDependencyDescriptor = AudioCodecDependencyDescriptor<
        AudioOptionsState,
        AudioFormatOption
    >(
        stateKeyPath: \.audioOptionsState,
        currentFormat: { $0.audioOptionsState.selectedOutputFormat },
        availableEncoders: \.audioRuntimeState.availableOutputEncoders,
        encoder: \.selectedOutputEncoder,
        audioMode: nil,
        bitRate: \.selectedOutputBitRate,
        supportsAudioTrack: { _ in true },
        includesAutoOption: { viewModel, format in
            viewModel.audioRuntimeState.media.sourceURL == nil && format.allowsFFmpegAutomaticAudioCodec
        },
        resolvedEncoders: { format in
            VideoConversionEngine.availableAudioEncoders(for: format)
        },
        placeholderEncoders: { format in
            ContentViewModelSupport.placeholderAudioOutputEncoders(for: format)
        },
        preferredEncoder: { format, options in
            ContentViewModelSupport.preferredAudioOutputEncoder(for: format, from: options)
        }
    )

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

    private func resolvedAudioEncoderOptions<State, Format>(
        _ availableEncoders: [AudioEncoderOption],
        for format: Format,
        using descriptor: AudioCodecDependencyDescriptor<State, Format>
    ) -> [AudioEncoderOption] {
        resolvedOptions(
            availableEncoders,
            autoOption: .auto,
            includesAutoOption: descriptor.includesAutoOption(self, format)
        )
    }

    private func normalizeAudioCodecDependencies<State, Format>(
        in state: inout State,
        format: Format,
        encoderOptions: [AudioEncoderOption],
        using descriptor: AudioCodecDependencyDescriptor<State, Format>
    ) {
        guard descriptor.supportsAudioTrack(format) else {
            state[keyPath: descriptor.encoder] = .auto
            if let audioMode = descriptor.audioMode {
                state[keyPath: audioMode] = .auto
            }
            state[keyPath: descriptor.bitRate] = .auto
            return
        }

        applyPreferredOptionIfNeeded(
            in: &state,
            selection: descriptor.encoder,
            options: encoderOptions,
            preferredOption: { descriptor.preferredEncoder(format, $0) }
        )
        if !state[keyPath: descriptor.encoder].supportsAudioBitRate {
            state[keyPath: descriptor.bitRate] = .auto
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

    private func applyAudioCodecDependencies<State: Equatable, Format>(
        using descriptor: AudioCodecDependencyDescriptor<State, Format>,
        availableEncoders: [AudioEncoderOption]
    ) {
        let format = descriptor.currentFormat(self)
        let encoderOptions = resolvedAudioEncoderOptions(
            availableEncoders,
            for: format,
            using: descriptor
        )

        self[keyPath: descriptor.availableEncoders] = availableEncoders
        updateState(descriptor.stateKeyPath) { state in
            normalizeAudioCodecDependencies(
                in: &state,
                format: format,
                encoderOptions: encoderOptions,
                using: descriptor
            )
        }
    }

    private func refreshAudioCodecDependencies<State: Equatable, Format>(
        using descriptor: AudioCodecDependencyDescriptor<State, Format>
    ) {
        let format = descriptor.currentFormat(self)
        applyAudioCodecDependencies(
            using: descriptor,
            availableEncoders: descriptor.resolvedEncoders(format)
        )
    }

    private func applyPlaceholderAudioCodecDependencies<State: Equatable, Format>(
        using descriptor: AudioCodecDependencyDescriptor<State, Format>
    ) {
        let format = descriptor.currentFormat(self)
        applyAudioCodecDependencies(
            using: descriptor,
            availableEncoders: descriptor.placeholderEncoders(format)
        )
    }

    private func resetVideoBitRateIfNeeded(in state: inout VideoOptionsState) {
        guard !state.selectedVideoEncoder.supportsVideoBitRate else { return }
        state.selectedVideoBitRate = .auto
    }

    var videoAudioEncoderSelectionOptions: [AudioEncoderOption] {
        let format = videoOptionsState.selectedOutputFormat
        guard format.supportsAudioTrack else { return [] }
        return resolvedAudioEncoderOptions(
            videoRuntimeState.availableAudioEncoders,
            for: format,
            using: Self.videoAudioCodecDependencyDescriptor
        )
    }

    var audioOutputEncoderSelectionOptions: [AudioEncoderOption] {
        let format = Self.audioOutputCodecDependencyDescriptor.currentFormat(self)
        return resolvedAudioEncoderOptions(
            audioRuntimeState.availableOutputEncoders,
            for: format,
            using: Self.audioOutputCodecDependencyDescriptor
        )
    }

    func refreshVideoCodecOptions() {
        let format = videoOptionsState.selectedOutputFormat
        let resolvedVideoEncoders = VideoConversionEngine.availableVideoEncoders(for: format)
        let resolvedAudioEncoders = Self.videoAudioCodecDependencyDescriptor.resolvedEncoders(format)
        let resolvedVideoEncoderOptions = resolvedOptions(
            resolvedVideoEncoders,
            autoOption: VideoEncoderOption.auto,
            includesAutoOption: format.avFileType != nil
        )
        let resolvedAudioEncoderOptions = format.supportsAudioTrack
            ? resolvedOptions(
                resolvedAudioEncoders,
                autoOption: .auto,
                includesAutoOption: Self.videoAudioCodecDependencyDescriptor.includesAutoOption(
                    self,
                    format
                )
            )
            : []

        videoRuntimeState.availableVideoEncoders = resolvedVideoEncoders
        self[keyPath: Self.videoAudioCodecDependencyDescriptor.availableEncoders] = resolvedAudioEncoders

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
            normalizeAudioCodecDependencies(
                in: &state,
                format: format,
                encoderOptions: resolvedAudioEncoderOptions,
                using: Self.videoAudioCodecDependencyDescriptor
            )
            resetVideoBitRateIfNeeded(in: &state)
        }
    }

    func applyPlaceholderVideoCodecOptions() {
        let format = videoOptionsState.selectedOutputFormat
        videoRuntimeState.availableVideoEncoders = ContentViewModelSupport.placeholderVideoEncoders(for: format)
        applyPlaceholderAudioCodecDependencies(using: Self.videoAudioCodecDependencyDescriptor)
        updateState(\.videoOptionsState) { state in
            resetVideoBitRateIfNeeded(in: &state)
        }
    }

    func refreshAudioCodecOptions() {
        refreshAudioCodecDependencies(using: Self.audioOutputCodecDependencyDescriptor)
    }

    func applyPlaceholderAudioCodecOptions() {
        applyPlaceholderAudioCodecDependencies(using: Self.audioOutputCodecDependencyDescriptor)
    }

    func normalizeVideoOptionDependencies() {
        let format = videoOptionsState.selectedOutputFormat
        let encoderOptions = format.supportsAudioTrack
            ? resolvedAudioEncoderOptions(
                videoRuntimeState.availableAudioEncoders,
                for: format,
                using: Self.videoAudioCodecDependencyDescriptor
            )
            : []
        updateState(\.videoOptionsState) { state in
            normalizeAudioCodecDependencies(
                in: &state,
                format: format,
                encoderOptions: encoderOptions,
                using: Self.videoAudioCodecDependencyDescriptor
            )
            resetVideoBitRateIfNeeded(in: &state)
        }
    }

    func normalizeAudioOptionDependencies() {
        let format = Self.audioOutputCodecDependencyDescriptor.currentFormat(self)
        let encoderOptions = resolvedAudioEncoderOptions(
            audioRuntimeState.availableOutputEncoders,
            for: format,
            using: Self.audioOutputCodecDependencyDescriptor
        )
        updateState(Self.audioOutputCodecDependencyDescriptor.stateKeyPath) { state in
            normalizeAudioCodecDependencies(
                in: &state,
                format: format,
                encoderOptions: encoderOptions,
                using: Self.audioOutputCodecDependencyDescriptor
            )
        }
    }
}
