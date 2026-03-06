import Foundation

extension ContentViewModel {
    // Video options
    var selectedOutputFormat: VideoFormatOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedOutputFormat) }
        set {
            updateState(\.videoOptionsState, value: \.selectedOutputFormat, to: newValue) {
                scheduleDeferredPersistenceAction(.videoFormatChange)
            }
        }
    }

    var selectedVideoEncoder: VideoEncoderOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedVideoEncoder) }
        set {
            updateState(\.videoOptionsState, value: \.selectedVideoEncoder, to: newValue) {
                scheduleDeferredPersistenceAction(.videoOptionNormalization)
            }
        }
    }

    var selectedResolution: ResolutionOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedResolution) }
        set {
            updateState(\.videoOptionsState, value: \.selectedResolution, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .video)
            }
        }
    }

    var selectedFrameRate: FrameRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedFrameRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedFrameRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .video)
            }
        }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedGIFPlaybackSpeed) }
        set {
            updateState(\.videoOptionsState, value: \.selectedGIFPlaybackSpeed, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .video)
            }
        }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedVideoBitRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedVideoBitRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .video)
            }
        }
    }

    var customVideoBitRate: String {
        get { stateValue(in: \.videoOptionsState, at: \.customVideoBitRate) }
        set {
            updateState(\.videoOptionsState, value: \.customVideoBitRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .video)
            }
        }
    }

    var selectedAudioEncoder: AudioEncoderOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedAudioEncoder) }
        set {
            updateState(\.videoOptionsState, value: \.selectedAudioEncoder, to: newValue) {
                scheduleDeferredPersistenceAction(.videoOptionNormalization)
            }
        }
    }

    var selectedAudioMode: AudioModeOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedAudioMode) }
        set {
            updateState(\.videoOptionsState, value: \.selectedAudioMode, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .video)
            }
        }
    }

    var selectedSampleRate: SampleRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedSampleRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedSampleRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .video)
            }
        }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedAudioBitRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedAudioBitRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .video)
            }
        }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedOutputFormat) }
        set {
            updateState(\.imageOptionsState, value: \.selectedOutputFormat, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .image)
            }
        }
    }

    var selectedImageResolution: ResolutionOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedResolution) }
        set {
            updateState(\.imageOptionsState, value: \.selectedResolution, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .image)
            }
        }
    }

    var selectedImageQuality: ImageQualityOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedQuality) }
        set {
            updateState(\.imageOptionsState, value: \.selectedQuality, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .image)
            }
        }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedPNGCompressionLevel) }
        set {
            updateState(\.imageOptionsState, value: \.selectedPNGCompressionLevel, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .image)
            }
        }
    }

    var preserveImageAnimation: Bool {
        get { stateValue(in: \.imageOptionsState, at: \.preserveAnimation) }
        set {
            updateState(\.imageOptionsState, value: \.preserveAnimation, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .image)
            }
        }
    }

    // Audio options
    var selectedAudioOutputFormat: AudioFormatOption {
        get { stateValue(in: \.audioOptionsState, at: \.selectedOutputFormat) }
        set {
            updateState(\.audioOptionsState, value: \.selectedOutputFormat, to: newValue) {
                scheduleDeferredPersistenceAction(.audioFormatChange)
            }
        }
    }

    var selectedAudioOutputEncoder: AudioEncoderOption {
        get { stateValue(in: \.audioOptionsState, at: \.selectedOutputEncoder) }
        set {
            updateState(\.audioOptionsState, value: \.selectedOutputEncoder, to: newValue) {
                scheduleDeferredPersistenceAction(.audioOptionNormalization)
            }
        }
    }

    var selectedAudioOutputMode: AudioModeOption {
        get { stateValue(in: \.audioOptionsState, at: \.selectedOutputMode) }
        set {
            updateState(\.audioOptionsState, value: \.selectedOutputMode, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .audio)
            }
        }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { stateValue(in: \.audioOptionsState, at: \.selectedOutputSampleRate) }
        set {
            updateState(\.audioOptionsState, value: \.selectedOutputSampleRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .audio)
            }
        }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { stateValue(in: \.audioOptionsState, at: \.selectedOutputBitRate) }
        set {
            updateState(\.audioOptionsState, value: \.selectedOutputBitRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(for: .audio)
            }
        }
    }
}
