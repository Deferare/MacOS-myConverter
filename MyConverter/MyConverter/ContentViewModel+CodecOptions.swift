import Foundation

extension ContentViewModel {
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

    func refreshVideoCodecOptions() {
        let format = selectedOutputFormat
        availableVideoEncoders = VideoConversionEngine.availableVideoEncoders(for: format)
        availableAudioEncoders = format.supportsAudioTrack
            ? VideoConversionEngine.availableAudioEncoders(for: format)
            : []

        updateSelectedOptionIfNeeded(
            options: availableVideoEncoders,
            selectedOptionKeyPath: \.selectedVideoEncoder,
            preferredOption: ContentViewModelSupport.preferredVideoEncoder(from:)
        )

        if format.supportsAudioTrack {
            updateSelectedOptionIfNeeded(
                options: availableAudioEncoders,
                selectedOptionKeyPath: \.selectedAudioEncoder,
                preferredOption: ContentViewModelSupport.preferredAudioEncoder(from:)
            )
        }

        normalizeVideoOptionDependencies()
    }

    func refreshAudioCodecOptions() {
        let format = selectedAudioOutputFormat
        availableAudioOutputEncoders = VideoConversionEngine.availableAudioEncoders(for: format)

        let effectiveOptions: [AudioEncoderOption]
        if !availableAudioOutputEncoders.isEmpty {
            effectiveOptions = availableAudioOutputEncoders
        } else if audioSourceURL == nil && format.allowsFFmpegAutomaticAudioCodec {
            effectiveOptions = [.auto]
        } else {
            effectiveOptions = []
        }

        updateSelectedOptionIfNeeded(
            options: effectiveOptions,
            selectedOptionKeyPath: \.selectedAudioOutputEncoder,
            preferredOption: {
                ContentViewModelSupport.preferredAudioOutputEncoder(for: format, from: $0)
            }
        )

        normalizeAudioOptionDependencies()
    }

    func normalizeVideoOptionDependencies() {
        if !selectedVideoEncoder.supportsVideoBitRate && selectedVideoBitRate != .auto {
            selectedVideoBitRate = .auto
        }

        if !shouldShowAudioSettings {
            if selectedAudioEncoder != .auto {
                selectedAudioEncoder = .auto
            }
            if selectedAudioMode != .auto {
                selectedAudioMode = .auto
            }
            if selectedAudioBitRate != .auto {
                selectedAudioBitRate = .auto
            }
            return
        }

        if !selectedAudioEncoder.supportsAudioBitRate && selectedAudioBitRate != .auto {
            selectedAudioBitRate = .auto
        }
    }

    func normalizeAudioOptionDependencies() {
        let options = audioOutputEncoderOptions
        if !options.isEmpty,
           !options.contains(selectedAudioOutputEncoder),
           let preferred = ContentViewModelSupport.preferredAudioOutputEncoder(
               for: selectedAudioOutputFormat,
               from: options
           ) {
            selectedAudioOutputEncoder = preferred
        }

        if !selectedAudioOutputEncoder.supportsAudioBitRate && selectedAudioOutputBitRate != .auto {
            selectedAudioOutputBitRate = .auto
        }
    }
}
