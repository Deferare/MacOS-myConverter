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
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedFrameRate: FrameRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedFrameRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedFrameRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedGIFPlaybackSpeed) }
        set {
            updateState(\.videoOptionsState, value: \.selectedGIFPlaybackSpeed, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedVideoBitRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedVideoBitRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var customVideoBitRate: String {
        get { stateValue(in: \.videoOptionsState, at: \.customVideoBitRate) }
        set {
            updateState(\.videoOptionsState, value: \.customVideoBitRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
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
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedSampleRate: SampleRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedSampleRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedSampleRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedAudioBitRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedAudioBitRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedOutputFormat) }
        set {
            updateState(\.imageOptionsState, value: \.selectedOutputFormat, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
            }
        }
    }

    var selectedImageResolution: ResolutionOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedResolution) }
        set {
            updateState(\.imageOptionsState, value: \.selectedResolution, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
            }
        }
    }

    var selectedImageQuality: ImageQualityOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedQuality) }
        set {
            updateState(\.imageOptionsState, value: \.selectedQuality, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
            }
        }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedPNGCompressionLevel) }
        set {
            updateState(\.imageOptionsState, value: \.selectedPNGCompressionLevel, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
            }
        }
    }

    var preserveImageAnimation: Bool {
        get { stateValue(in: \.imageOptionsState, at: \.preserveAnimation) }
        set {
            updateState(\.imageOptionsState, value: \.preserveAnimation, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
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
                persistCurrentAudioSettingsIfNeeded()
            }
        }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { stateValue(in: \.audioOptionsState, at: \.selectedOutputSampleRate) }
        set {
            updateState(\.audioOptionsState, value: \.selectedOutputSampleRate, to: newValue) {
                persistCurrentAudioSettingsIfNeeded()
            }
        }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { stateValue(in: \.audioOptionsState, at: \.selectedOutputBitRate) }
        set {
            updateState(\.audioOptionsState, value: \.selectedOutputBitRate, to: newValue) {
                persistCurrentAudioSettingsIfNeeded()
            }
        }
    }
}
