import Foundation

extension ContentViewModel {
    private enum OptionWriteAction {
        case persist(MediaKind)
        case deferred(DeferredPersistenceAction)

        func apply(to viewModel: ContentViewModel) {
            switch self {
            case .persist(let kind):
                viewModel.persistCurrentSourceSettingsIfNeeded(for: kind)
            case .deferred(let action):
                viewModel.scheduleDeferredPersistenceAction(action)
            }
        }
    }

    private func optionValue<State, Value>(
        in stateKeyPath: KeyPath<ContentViewModel, State>,
        _ valueKeyPath: KeyPath<State, Value>
    ) -> Value {
        stateValue(in: stateKeyPath, at: valueKeyPath)
    }

    private func setOptionValue<State, Value: Equatable>(
        in stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        after action: @escaping () -> Void = {}
    ) {
        updateState(stateKeyPath, value: valueKeyPath, to: newValue, after: action)
    }

    private func setOptionValue<State, Value: Equatable>(
        in stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        using action: OptionWriteAction
    ) {
        setOptionValue(in: stateKeyPath, valueKeyPath, to: newValue) {
            action.apply(to: self)
        }
    }

    private func persistOption<State, Value: Equatable>(
        in stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        for kind: MediaKind
    ) {
        setOptionValue(in: stateKeyPath, valueKeyPath, to: newValue, using: .persist(kind))
    }

    private func deferOption<State, Value: Equatable>(
        in stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        action: DeferredPersistenceAction
    ) {
        setOptionValue(in: stateKeyPath, valueKeyPath, to: newValue, using: .deferred(action))
    }

    // Video options
    var selectedOutputFormat: VideoFormatOption {
        get { optionValue(in: \.videoOptionsState, \.selectedOutputFormat) }
        set { deferOption(in: \.videoOptionsState, \.selectedOutputFormat, to: newValue, action: .videoFormatChange) }
    }

    var selectedVideoEncoder: VideoEncoderOption {
        get { optionValue(in: \.videoOptionsState, \.selectedVideoEncoder) }
        set { deferOption(in: \.videoOptionsState, \.selectedVideoEncoder, to: newValue, action: .videoOptionNormalization) }
    }

    var selectedResolution: ResolutionOption {
        get { optionValue(in: \.videoOptionsState, \.selectedResolution) }
        set { persistOption(in: \.videoOptionsState, \.selectedResolution, to: newValue, for: .video) }
    }

    var selectedFrameRate: FrameRateOption {
        get { optionValue(in: \.videoOptionsState, \.selectedFrameRate) }
        set { persistOption(in: \.videoOptionsState, \.selectedFrameRate, to: newValue, for: .video) }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { optionValue(in: \.videoOptionsState, \.selectedGIFPlaybackSpeed) }
        set { persistOption(in: \.videoOptionsState, \.selectedGIFPlaybackSpeed, to: newValue, for: .video) }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { optionValue(in: \.videoOptionsState, \.selectedVideoBitRate) }
        set { persistOption(in: \.videoOptionsState, \.selectedVideoBitRate, to: newValue, for: .video) }
    }

    var customVideoBitRate: String {
        get { optionValue(in: \.videoOptionsState, \.customVideoBitRate) }
        set { persistOption(in: \.videoOptionsState, \.customVideoBitRate, to: newValue, for: .video) }
    }

    var selectedAudioEncoder: AudioEncoderOption {
        get { optionValue(in: \.videoOptionsState, \.selectedAudioEncoder) }
        set { deferOption(in: \.videoOptionsState, \.selectedAudioEncoder, to: newValue, action: .videoOptionNormalization) }
    }

    var selectedAudioMode: AudioModeOption {
        get { optionValue(in: \.videoOptionsState, \.selectedAudioMode) }
        set { persistOption(in: \.videoOptionsState, \.selectedAudioMode, to: newValue, for: .video) }
    }

    var selectedSampleRate: SampleRateOption {
        get { optionValue(in: \.videoOptionsState, \.selectedSampleRate) }
        set { persistOption(in: \.videoOptionsState, \.selectedSampleRate, to: newValue, for: .video) }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { optionValue(in: \.videoOptionsState, \.selectedAudioBitRate) }
        set { persistOption(in: \.videoOptionsState, \.selectedAudioBitRate, to: newValue, for: .video) }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { optionValue(in: \.imageOptionsState, \.selectedOutputFormat) }
        set { persistOption(in: \.imageOptionsState, \.selectedOutputFormat, to: newValue, for: .image) }
    }

    var selectedImageResolution: ResolutionOption {
        get { optionValue(in: \.imageOptionsState, \.selectedResolution) }
        set { persistOption(in: \.imageOptionsState, \.selectedResolution, to: newValue, for: .image) }
    }

    var selectedImageQuality: ImageQualityOption {
        get { optionValue(in: \.imageOptionsState, \.selectedQuality) }
        set { persistOption(in: \.imageOptionsState, \.selectedQuality, to: newValue, for: .image) }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { optionValue(in: \.imageOptionsState, \.selectedPNGCompressionLevel) }
        set { persistOption(in: \.imageOptionsState, \.selectedPNGCompressionLevel, to: newValue, for: .image) }
    }

    var preserveImageAnimation: Bool {
        get { optionValue(in: \.imageOptionsState, \.preserveAnimation) }
        set { persistOption(in: \.imageOptionsState, \.preserveAnimation, to: newValue, for: .image) }
    }

    // Audio options
    var selectedAudioOutputFormat: AudioFormatOption {
        get { optionValue(in: \.audioOptionsState, \.selectedOutputFormat) }
        set { deferOption(in: \.audioOptionsState, \.selectedOutputFormat, to: newValue, action: .audioFormatChange) }
    }

    var selectedAudioOutputEncoder: AudioEncoderOption {
        get { optionValue(in: \.audioOptionsState, \.selectedOutputEncoder) }
        set { deferOption(in: \.audioOptionsState, \.selectedOutputEncoder, to: newValue, action: .audioOptionNormalization) }
    }

    var selectedAudioOutputMode: AudioModeOption {
        get { optionValue(in: \.audioOptionsState, \.selectedOutputMode) }
        set { persistOption(in: \.audioOptionsState, \.selectedOutputMode, to: newValue, for: .audio) }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { optionValue(in: \.audioOptionsState, \.selectedOutputSampleRate) }
        set { persistOption(in: \.audioOptionsState, \.selectedOutputSampleRate, to: newValue, for: .audio) }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { optionValue(in: \.audioOptionsState, \.selectedOutputBitRate) }
        set { persistOption(in: \.audioOptionsState, \.selectedOutputBitRate, to: newValue, for: .audio) }
    }
}
