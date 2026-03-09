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

    func updateSelectedOptionIfNeeded<Option: Equatable>(
        options: [Option],
        selectedOptionKeyPath: ReferenceWritableKeyPath<ContentViewModel, Option>,
        preferredOption: ([Option]) -> Option?
    ) {
        let selected = self[keyPath: selectedOptionKeyPath]
        guard !options.contains(selected),
              let preferred = preferredOption(options) else {
            return
        }
        self[keyPath: selectedOptionKeyPath] = preferred
    }

    func resetSelectedOptionIfNeeded<Option: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<ContentViewModel, Option>,
        to fallback: Option
    ) {
        guard self[keyPath: keyPath] != fallback else { return }
        self[keyPath: keyPath] = fallback
    }

    func refreshVideoCodecOptions() {
        let format = selectedOutputFormat
        availableVideoEncoders = VideoConversionEngine.availableVideoEncoders(for: format)
        availableAudioEncoders = format.supportsAudioTrack
            ? VideoConversionEngine.availableAudioEncoders(for: format)
            : []

        updateSelectedOptionIfNeeded(
            options: videoEncoderOptions,
            selectedOptionKeyPath: \.selectedVideoEncoder,
            preferredOption: ContentViewModelSupport.preferredVideoEncoder(from:)
        )

        if format.supportsAudioTrack {
            updateSelectedOptionIfNeeded(
                options: audioEncoderOptions,
                selectedOptionKeyPath: \.selectedAudioEncoder,
                preferredOption: ContentViewModelSupport.preferredAudioEncoder(from:)
            )
        }

        normalizeVideoOptionDependencies()
    }

    func refreshAudioCodecOptions() {
        let format = selectedAudioOutputFormat
        availableAudioOutputEncoders = VideoConversionEngine.availableAudioEncoders(for: format)

        updateSelectedOptionIfNeeded(
            options: audioOutputEncoderOptions,
            selectedOptionKeyPath: \.selectedAudioOutputEncoder,
            preferredOption: { ContentViewModelSupport.preferredAudioOutputEncoder(for: format, from: $0) }
        )

        normalizeAudioOptionDependencies()
    }

    func normalizeVideoOptionDependencies() {
        if !selectedVideoEncoder.supportsVideoBitRate {
            resetSelectedOptionIfNeeded(\.selectedVideoBitRate, to: .auto)
        }

        if !shouldShowAudioSettings {
            resetSelectedOptionIfNeeded(\.selectedAudioEncoder, to: .auto)
            resetSelectedOptionIfNeeded(\.selectedAudioMode, to: .auto)
            resetSelectedOptionIfNeeded(\.selectedAudioBitRate, to: .auto)
            return
        }

        if !selectedAudioEncoder.supportsAudioBitRate {
            resetSelectedOptionIfNeeded(\.selectedAudioBitRate, to: .auto)
        }
    }

    func normalizeAudioOptionDependencies() {
        updateSelectedOptionIfNeeded(
            options: audioOutputEncoderOptions,
            selectedOptionKeyPath: \.selectedAudioOutputEncoder,
            preferredOption: preferredAudioOutputEncoderOption(from:)
        )

        if !selectedAudioOutputEncoder.supportsAudioBitRate {
            resetSelectedOptionIfNeeded(\.selectedAudioOutputBitRate, to: .auto)
        }
    }
}
