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
                persistCurrentSourceSettingsIfNeeded(using: videoSettingsFlowDescriptor())
            }
        }
    }

    var selectedFrameRate: FrameRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedFrameRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedFrameRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: videoSettingsFlowDescriptor())
            }
        }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedGIFPlaybackSpeed) }
        set {
            updateState(\.videoOptionsState, value: \.selectedGIFPlaybackSpeed, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: videoSettingsFlowDescriptor())
            }
        }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedVideoBitRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedVideoBitRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: videoSettingsFlowDescriptor())
            }
        }
    }

    var customVideoBitRate: String {
        get { stateValue(in: \.videoOptionsState, at: \.customVideoBitRate) }
        set {
            updateState(\.videoOptionsState, value: \.customVideoBitRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: videoSettingsFlowDescriptor())
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
                persistCurrentSourceSettingsIfNeeded(using: videoSettingsFlowDescriptor())
            }
        }
    }

    var selectedSampleRate: SampleRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedSampleRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedSampleRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: videoSettingsFlowDescriptor())
            }
        }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { stateValue(in: \.videoOptionsState, at: \.selectedAudioBitRate) }
        set {
            updateState(\.videoOptionsState, value: \.selectedAudioBitRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: videoSettingsFlowDescriptor())
            }
        }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedOutputFormat) }
        set {
            updateState(\.imageOptionsState, value: \.selectedOutputFormat, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: imageSettingsFlowDescriptor())
            }
        }
    }

    var selectedImageResolution: ResolutionOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedResolution) }
        set {
            updateState(\.imageOptionsState, value: \.selectedResolution, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: imageSettingsFlowDescriptor())
            }
        }
    }

    var selectedImageQuality: ImageQualityOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedQuality) }
        set {
            updateState(\.imageOptionsState, value: \.selectedQuality, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: imageSettingsFlowDescriptor())
            }
        }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { stateValue(in: \.imageOptionsState, at: \.selectedPNGCompressionLevel) }
        set {
            updateState(\.imageOptionsState, value: \.selectedPNGCompressionLevel, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: imageSettingsFlowDescriptor())
            }
        }
    }

    var preserveImageAnimation: Bool {
        get { stateValue(in: \.imageOptionsState, at: \.preserveAnimation) }
        set {
            updateState(\.imageOptionsState, value: \.preserveAnimation, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: imageSettingsFlowDescriptor())
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
                persistCurrentSourceSettingsIfNeeded(using: audioSettingsFlowDescriptor())
            }
        }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { stateValue(in: \.audioOptionsState, at: \.selectedOutputSampleRate) }
        set {
            updateState(\.audioOptionsState, value: \.selectedOutputSampleRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: audioSettingsFlowDescriptor())
            }
        }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { stateValue(in: \.audioOptionsState, at: \.selectedOutputBitRate) }
        set {
            updateState(\.audioOptionsState, value: \.selectedOutputBitRate, to: newValue) {
                persistCurrentSourceSettingsIfNeeded(using: audioSettingsFlowDescriptor())
            }
        }
    }
}
