import Foundation

extension ContentViewModel {
    private struct OptionStateDescriptor<State> {
        let state: StateProxyDescriptor<State>
        let persistKind: MediaKind
    }

    private enum OutputOptionPersistence {
        case persist
        case deferred(DeferredPersistenceAction)
    }

    private static let videoOptionsDescriptor = OptionStateDescriptor(
        state: StateProxyDescriptor(stateKeyPath: \.videoOptionsState),
        persistKind: .video
    )

    private static let imageOptionsDescriptor = OptionStateDescriptor(
        state: StateProxyDescriptor(stateKeyPath: \.imageOptionsState),
        persistKind: .image
    )

    private static let audioOptionsDescriptor = OptionStateDescriptor(
        state: StateProxyDescriptor(stateKeyPath: \.audioOptionsState),
        persistKind: .audio
    )

    private func optionValue<State, Value>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: KeyPath<State, Value>
    ) -> Value {
        stateValue(using: descriptor.state, at: valueKeyPath)
    }

    private func setOptionValue<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        after action: @escaping () -> Void = {}
    ) {
        updateState(using: descriptor.state, value: valueKeyPath, to: newValue, after: action)
    }

    private func setOutputAffectingOption<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        persistence: OutputOptionPersistence? = nil
    ) {
        setOptionValue(in: descriptor, valueKeyPath, to: newValue) {
            self.resetConversionOutputs(for: descriptor.persistKind)
            switch persistence {
            case .persist:
                self.persistCurrentSourceSettingsIfNeeded(for: descriptor.persistKind)
            case .deferred(let action):
                self.scheduleDeferredPersistenceAction(action)
            case nil:
                break
            }
        }
    }

    // Video options
    var selectedOutputFormat: VideoFormatOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedOutputFormat) }
        set {
            setOutputAffectingOption(
                in: Self.videoOptionsDescriptor,
                \.selectedOutputFormat,
                to: newValue,
                persistence: .deferred(.videoFormatChange)
            )
        }
    }

    var selectedVideoEncoder: VideoEncoderOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedVideoEncoder) }
        set {
            setOutputAffectingOption(
                in: Self.videoOptionsDescriptor,
                \.selectedVideoEncoder,
                to: newValue,
                persistence: .deferred(.videoOptionNormalization)
            )
        }
    }

    var selectedResolution: ResolutionOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedResolution) }
        set { setOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedResolution, to: newValue, persistence: .persist) }
    }

    var selectedFrameRate: FrameRateOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedFrameRate) }
        set { setOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedFrameRate, to: newValue, persistence: .persist) }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedGIFPlaybackSpeed) }
        set { setOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedGIFPlaybackSpeed, to: newValue, persistence: .persist) }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedVideoBitRate) }
        set { setOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedVideoBitRate, to: newValue, persistence: .persist) }
    }

    var customVideoBitRate: String {
        get { optionValue(in: Self.videoOptionsDescriptor, \.customVideoBitRate) }
        set { setOutputAffectingOption(in: Self.videoOptionsDescriptor, \.customVideoBitRate, to: newValue, persistence: .persist) }
    }

    var selectedAudioEncoder: AudioEncoderOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedAudioEncoder) }
        set {
            setOutputAffectingOption(
                in: Self.videoOptionsDescriptor,
                \.selectedAudioEncoder,
                to: newValue,
                persistence: .deferred(.videoOptionNormalization)
            )
        }
    }

    var selectedAudioMode: AudioModeOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedAudioMode) }
        set { setOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedAudioMode, to: newValue, persistence: .persist) }
    }

    var selectedSampleRate: SampleRateOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedSampleRate) }
        set { setOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedSampleRate, to: newValue, persistence: .persist) }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedAudioBitRate) }
        set { setOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedAudioBitRate, to: newValue, persistence: .persist) }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { optionValue(in: Self.imageOptionsDescriptor, \.selectedOutputFormat) }
        set { setOutputAffectingOption(in: Self.imageOptionsDescriptor, \.selectedOutputFormat, to: newValue, persistence: .persist) }
    }

    var selectedImageResolution: ResolutionOption {
        get { optionValue(in: Self.imageOptionsDescriptor, \.selectedResolution) }
        set { setOutputAffectingOption(in: Self.imageOptionsDescriptor, \.selectedResolution, to: newValue, persistence: .persist) }
    }

    var selectedImageQuality: ImageQualityOption {
        get { optionValue(in: Self.imageOptionsDescriptor, \.selectedQuality) }
        set { setOutputAffectingOption(in: Self.imageOptionsDescriptor, \.selectedQuality, to: newValue, persistence: .persist) }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { optionValue(in: Self.imageOptionsDescriptor, \.selectedPNGCompressionLevel) }
        set { setOutputAffectingOption(in: Self.imageOptionsDescriptor, \.selectedPNGCompressionLevel, to: newValue, persistence: .persist) }
    }

    var preserveImageAnimation: Bool {
        get { optionValue(in: Self.imageOptionsDescriptor, \.preserveAnimation) }
        set { setOutputAffectingOption(in: Self.imageOptionsDescriptor, \.preserveAnimation, to: newValue, persistence: .persist) }
    }

    // Audio options
    var selectedAudioOutputFormat: AudioFormatOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputFormat) }
        set {
            setOutputAffectingOption(
                in: Self.audioOptionsDescriptor,
                \.selectedOutputFormat,
                to: newValue,
                persistence: .deferred(.audioFormatChange)
            )
        }
    }

    var selectedAudioOutputEncoder: AudioEncoderOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputEncoder) }
        set {
            setOutputAffectingOption(
                in: Self.audioOptionsDescriptor,
                \.selectedOutputEncoder,
                to: newValue,
                persistence: .deferred(.audioOptionNormalization)
            )
        }
    }

    var selectedAudioOutputMode: AudioModeOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputMode) }
        set { setOutputAffectingOption(in: Self.audioOptionsDescriptor, \.selectedOutputMode, to: newValue, persistence: .persist) }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputSampleRate) }
        set { setOutputAffectingOption(in: Self.audioOptionsDescriptor, \.selectedOutputSampleRate, to: newValue, persistence: .persist) }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputBitRate) }
        set { setOutputAffectingOption(in: Self.audioOptionsDescriptor, \.selectedOutputBitRate, to: newValue, persistence: .persist) }
    }

}
