import Foundation

extension ContentViewModel {
    private struct OptionStateDescriptor<State> {
        let state: StateProxyDescriptor<State>
        let persistKind: MediaKind
    }

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

    private var videoOptionsDescriptor: OptionStateDescriptor<VideoOptionsState> {
        OptionStateDescriptor(
            state: StateProxyDescriptor(stateKeyPath: \.videoOptionsState),
            persistKind: .video
        )
    }

    private var imageOptionsDescriptor: OptionStateDescriptor<ImageOptionsState> {
        OptionStateDescriptor(
            state: StateProxyDescriptor(stateKeyPath: \.imageOptionsState),
            persistKind: .image
        )
    }

    private var audioOptionsDescriptor: OptionStateDescriptor<AudioOptionsState> {
        OptionStateDescriptor(
            state: StateProxyDescriptor(stateKeyPath: \.audioOptionsState),
            persistKind: .audio
        )
    }

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

    private func setOptionValue<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        using action: OptionWriteAction
    ) {
        setOptionValue(in: descriptor, valueKeyPath, to: newValue) {
            action.apply(to: self)
        }
    }

    private func setOutputAffectingOption<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value
    ) {
        setOptionValue(in: descriptor, valueKeyPath, to: newValue) {
            self.resetConversionOutputs(for: descriptor.persistKind)
        }
    }

    private func persistOutputAffectingOption<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value
    ) {
        setOptionValue(in: descriptor, valueKeyPath, to: newValue) {
            self.resetConversionOutputs(for: descriptor.persistKind)
            self.persistCurrentSourceSettingsIfNeeded(for: descriptor.persistKind)
        }
    }

    private func deferOutputAffectingOption<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        action: DeferredPersistenceAction
    ) {
        setOptionValue(in: descriptor, valueKeyPath, to: newValue) {
            self.resetConversionOutputs(for: descriptor.persistKind)
            self.scheduleDeferredPersistenceAction(action)
        }
    }

    private func persistOption<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value
    ) {
        setOptionValue(in: descriptor, valueKeyPath, to: newValue, using: .persist(descriptor.persistKind))
    }

    private func deferOption<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        action: DeferredPersistenceAction
    ) {
        setOptionValue(in: descriptor, valueKeyPath, to: newValue, using: .deferred(action))
    }

    // Video options
    var selectedOutputFormat: VideoFormatOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedOutputFormat) }
        set {
            deferOutputAffectingOption(
                in: videoOptionsDescriptor,
                \.selectedOutputFormat,
                to: newValue,
                action: .videoFormatChange
            )
        }
    }

    var selectedVideoEncoder: VideoEncoderOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedVideoEncoder) }
        set {
            deferOutputAffectingOption(
                in: videoOptionsDescriptor,
                \.selectedVideoEncoder,
                to: newValue,
                action: .videoOptionNormalization
            )
        }
    }

    var selectedResolution: ResolutionOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedResolution) }
        set { persistOutputAffectingOption(in: videoOptionsDescriptor, \.selectedResolution, to: newValue) }
    }

    var selectedFrameRate: FrameRateOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedFrameRate) }
        set { persistOutputAffectingOption(in: videoOptionsDescriptor, \.selectedFrameRate, to: newValue) }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedGIFPlaybackSpeed) }
        set { persistOutputAffectingOption(in: videoOptionsDescriptor, \.selectedGIFPlaybackSpeed, to: newValue) }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedVideoBitRate) }
        set { persistOutputAffectingOption(in: videoOptionsDescriptor, \.selectedVideoBitRate, to: newValue) }
    }

    var customVideoBitRate: String {
        get { optionValue(in: videoOptionsDescriptor, \.customVideoBitRate) }
        set { persistOutputAffectingOption(in: videoOptionsDescriptor, \.customVideoBitRate, to: newValue) }
    }

    var selectedAudioEncoder: AudioEncoderOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedAudioEncoder) }
        set {
            deferOutputAffectingOption(
                in: videoOptionsDescriptor,
                \.selectedAudioEncoder,
                to: newValue,
                action: .videoOptionNormalization
            )
        }
    }

    var selectedAudioMode: AudioModeOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedAudioMode) }
        set { persistOutputAffectingOption(in: videoOptionsDescriptor, \.selectedAudioMode, to: newValue) }
    }

    var selectedSampleRate: SampleRateOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedSampleRate) }
        set { persistOutputAffectingOption(in: videoOptionsDescriptor, \.selectedSampleRate, to: newValue) }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { optionValue(in: videoOptionsDescriptor, \.selectedAudioBitRate) }
        set { persistOutputAffectingOption(in: videoOptionsDescriptor, \.selectedAudioBitRate, to: newValue) }
    }

    var selectedVideoOutputDirectoryURL: URL? {
        get { optionValue(in: videoOptionsDescriptor, \.selectedOutputDirectoryURL) }
        set { setOutputAffectingOption(in: videoOptionsDescriptor, \.selectedOutputDirectoryURL, to: newValue) }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { optionValue(in: imageOptionsDescriptor, \.selectedOutputFormat) }
        set { persistOutputAffectingOption(in: imageOptionsDescriptor, \.selectedOutputFormat, to: newValue) }
    }

    var selectedImageResolution: ResolutionOption {
        get { optionValue(in: imageOptionsDescriptor, \.selectedResolution) }
        set { persistOutputAffectingOption(in: imageOptionsDescriptor, \.selectedResolution, to: newValue) }
    }

    var selectedImageQuality: ImageQualityOption {
        get { optionValue(in: imageOptionsDescriptor, \.selectedQuality) }
        set { persistOutputAffectingOption(in: imageOptionsDescriptor, \.selectedQuality, to: newValue) }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { optionValue(in: imageOptionsDescriptor, \.selectedPNGCompressionLevel) }
        set { persistOutputAffectingOption(in: imageOptionsDescriptor, \.selectedPNGCompressionLevel, to: newValue) }
    }

    var preserveImageAnimation: Bool {
        get { optionValue(in: imageOptionsDescriptor, \.preserveAnimation) }
        set { persistOutputAffectingOption(in: imageOptionsDescriptor, \.preserveAnimation, to: newValue) }
    }

    var selectedImageOutputDirectoryURL: URL? {
        get { optionValue(in: imageOptionsDescriptor, \.selectedOutputDirectoryURL) }
        set { setOutputAffectingOption(in: imageOptionsDescriptor, \.selectedOutputDirectoryURL, to: newValue) }
    }

    // Audio options
    var selectedAudioOutputFormat: AudioFormatOption {
        get { optionValue(in: audioOptionsDescriptor, \.selectedOutputFormat) }
        set {
            deferOutputAffectingOption(
                in: audioOptionsDescriptor,
                \.selectedOutputFormat,
                to: newValue,
                action: .audioFormatChange
            )
        }
    }

    var selectedAudioOutputEncoder: AudioEncoderOption {
        get { optionValue(in: audioOptionsDescriptor, \.selectedOutputEncoder) }
        set {
            deferOutputAffectingOption(
                in: audioOptionsDescriptor,
                \.selectedOutputEncoder,
                to: newValue,
                action: .audioOptionNormalization
            )
        }
    }

    var selectedAudioOutputMode: AudioModeOption {
        get { optionValue(in: audioOptionsDescriptor, \.selectedOutputMode) }
        set { persistOutputAffectingOption(in: audioOptionsDescriptor, \.selectedOutputMode, to: newValue) }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { optionValue(in: audioOptionsDescriptor, \.selectedOutputSampleRate) }
        set { persistOutputAffectingOption(in: audioOptionsDescriptor, \.selectedOutputSampleRate, to: newValue) }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { optionValue(in: audioOptionsDescriptor, \.selectedOutputBitRate) }
        set { persistOutputAffectingOption(in: audioOptionsDescriptor, \.selectedOutputBitRate, to: newValue) }
    }

    var selectedAudioOutputDirectoryURL: URL? {
        get { optionValue(in: audioOptionsDescriptor, \.selectedOutputDirectoryURL) }
        set { setOutputAffectingOption(in: audioOptionsDescriptor, \.selectedOutputDirectoryURL, to: newValue) }
    }
}
