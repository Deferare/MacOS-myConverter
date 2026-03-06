import Foundation

extension ContentViewModel {
    // Video options
    var selectedOutputFormat: VideoFormatOption {
        get { videoOptionsValue(\.selectedOutputFormat) }
        set {
            updateVideoOptions(\.selectedOutputFormat, to: newValue) {
                scheduleDeferredPersistenceAction(.videoFormatChange)
            }
        }
    }

    var selectedVideoEncoder: VideoEncoderOption {
        get { videoOptionsValue(\.selectedVideoEncoder) }
        set {
            updateVideoOptions(\.selectedVideoEncoder, to: newValue) {
                scheduleDeferredPersistenceAction(.videoOptionNormalization)
            }
        }
    }

    var selectedResolution: ResolutionOption {
        get { videoOptionsValue(\.selectedResolution) }
        set {
            updateVideoOptions(\.selectedResolution, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedFrameRate: FrameRateOption {
        get { videoOptionsValue(\.selectedFrameRate) }
        set {
            updateVideoOptions(\.selectedFrameRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { videoOptionsValue(\.selectedGIFPlaybackSpeed) }
        set {
            updateVideoOptions(\.selectedGIFPlaybackSpeed, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { videoOptionsValue(\.selectedVideoBitRate) }
        set {
            updateVideoOptions(\.selectedVideoBitRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var customVideoBitRate: String {
        get { videoOptionsValue(\.customVideoBitRate) }
        set {
            updateVideoOptions(\.customVideoBitRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedAudioEncoder: AudioEncoderOption {
        get { videoOptionsValue(\.selectedAudioEncoder) }
        set {
            updateVideoOptions(\.selectedAudioEncoder, to: newValue) {
                scheduleDeferredPersistenceAction(.videoOptionNormalization)
            }
        }
    }

    var selectedAudioMode: AudioModeOption {
        get { videoOptionsValue(\.selectedAudioMode) }
        set {
            updateVideoOptions(\.selectedAudioMode, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedSampleRate: SampleRateOption {
        get { videoOptionsValue(\.selectedSampleRate) }
        set {
            updateVideoOptions(\.selectedSampleRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { videoOptionsValue(\.selectedAudioBitRate) }
        set {
            updateVideoOptions(\.selectedAudioBitRate, to: newValue) {
                persistCurrentSettingsIfNeeded()
            }
        }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { imageOptionsValue(\.selectedOutputFormat) }
        set {
            updateImageOptions(\.selectedOutputFormat, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
            }
        }
    }

    var selectedImageResolution: ResolutionOption {
        get { imageOptionsValue(\.selectedResolution) }
        set {
            updateImageOptions(\.selectedResolution, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
            }
        }
    }

    var selectedImageQuality: ImageQualityOption {
        get { imageOptionsValue(\.selectedQuality) }
        set {
            updateImageOptions(\.selectedQuality, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
            }
        }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { imageOptionsValue(\.selectedPNGCompressionLevel) }
        set {
            updateImageOptions(\.selectedPNGCompressionLevel, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
            }
        }
    }

    var preserveImageAnimation: Bool {
        get { imageOptionsValue(\.preserveAnimation) }
        set {
            updateImageOptions(\.preserveAnimation, to: newValue) {
                persistCurrentImageSettingsIfNeeded()
            }
        }
    }

    // Audio options
    var selectedAudioOutputFormat: AudioFormatOption {
        get { audioOptionsValue(\.selectedOutputFormat) }
        set {
            updateAudioOptions(\.selectedOutputFormat, to: newValue) {
                scheduleDeferredPersistenceAction(.audioFormatChange)
            }
        }
    }

    var selectedAudioOutputEncoder: AudioEncoderOption {
        get { audioOptionsValue(\.selectedOutputEncoder) }
        set {
            updateAudioOptions(\.selectedOutputEncoder, to: newValue) {
                scheduleDeferredPersistenceAction(.audioOptionNormalization)
            }
        }
    }

    var selectedAudioOutputMode: AudioModeOption {
        get { audioOptionsValue(\.selectedOutputMode) }
        set {
            updateAudioOptions(\.selectedOutputMode, to: newValue) {
                persistCurrentAudioSettingsIfNeeded()
            }
        }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { audioOptionsValue(\.selectedOutputSampleRate) }
        set {
            updateAudioOptions(\.selectedOutputSampleRate, to: newValue) {
                persistCurrentAudioSettingsIfNeeded()
            }
        }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { audioOptionsValue(\.selectedOutputBitRate) }
        set {
            updateAudioOptions(\.selectedOutputBitRate, to: newValue) {
                persistCurrentAudioSettingsIfNeeded()
            }
        }
    }
}
