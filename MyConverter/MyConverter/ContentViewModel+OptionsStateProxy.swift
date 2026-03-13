import Foundation

extension ContentViewModel {
    private struct OptionStateDescriptor<State> {
        let state: StateProxyDescriptor<State>
        let persistKind: MediaKind
    }

    private struct OptionWriteAction {
        let apply: (ContentViewModel) -> Void

        static func persist(_ kind: MediaKind) -> Self {
            Self { viewModel in
                viewModel.persistCurrentSourceSettingsIfNeeded(for: kind)
            }
        }

        static func deferred(_ action: DeferredPersistenceAction) -> Self {
            Self { viewModel in
                viewModel.scheduleDeferredPersistenceAction(action)
            }
        }
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

    private func setOptionValue<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        using action: OptionWriteAction
    ) {
        setOptionValue(in: descriptor, valueKeyPath, to: newValue) {
            action.apply(self)
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
        setOptionValue(
            in: descriptor,
            valueKeyPath,
            to: newValue,
            using: .persist(descriptor.persistKind)
        )
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
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedOutputFormat) }
        set {
            deferOutputAffectingOption(
                in: Self.videoOptionsDescriptor,
                \.selectedOutputFormat,
                to: newValue,
                action: .videoFormatChange
            )
        }
    }

    var selectedVideoEncoder: VideoEncoderOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedVideoEncoder) }
        set {
            deferOutputAffectingOption(
                in: Self.videoOptionsDescriptor,
                \.selectedVideoEncoder,
                to: newValue,
                action: .videoOptionNormalization
            )
        }
    }

    var selectedResolution: ResolutionOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedResolution) }
        set { persistOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedResolution, to: newValue) }
    }

    var selectedFrameRate: FrameRateOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedFrameRate) }
        set { persistOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedFrameRate, to: newValue) }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedGIFPlaybackSpeed) }
        set { persistOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedGIFPlaybackSpeed, to: newValue) }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedVideoBitRate) }
        set { persistOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedVideoBitRate, to: newValue) }
    }

    var customVideoBitRate: String {
        get { optionValue(in: Self.videoOptionsDescriptor, \.customVideoBitRate) }
        set { persistOutputAffectingOption(in: Self.videoOptionsDescriptor, \.customVideoBitRate, to: newValue) }
    }

    var selectedAudioEncoder: AudioEncoderOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedAudioEncoder) }
        set {
            deferOutputAffectingOption(
                in: Self.videoOptionsDescriptor,
                \.selectedAudioEncoder,
                to: newValue,
                action: .videoOptionNormalization
            )
        }
    }

    var selectedAudioMode: AudioModeOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedAudioMode) }
        set { persistOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedAudioMode, to: newValue) }
    }

    var selectedSampleRate: SampleRateOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedSampleRate) }
        set { persistOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedSampleRate, to: newValue) }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedAudioBitRate) }
        set { persistOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedAudioBitRate, to: newValue) }
    }

    var selectedVideoOutputDirectoryURL: URL? {
        get { optionValue(in: Self.videoOptionsDescriptor, \.selectedOutputDirectoryURL) }
        set { setOutputAffectingOption(in: Self.videoOptionsDescriptor, \.selectedOutputDirectoryURL, to: newValue) }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { optionValue(in: Self.imageOptionsDescriptor, \.selectedOutputFormat) }
        set { persistOutputAffectingOption(in: Self.imageOptionsDescriptor, \.selectedOutputFormat, to: newValue) }
    }

    var selectedImageResolution: ResolutionOption {
        get { optionValue(in: Self.imageOptionsDescriptor, \.selectedResolution) }
        set { persistOutputAffectingOption(in: Self.imageOptionsDescriptor, \.selectedResolution, to: newValue) }
    }

    var selectedImageQuality: ImageQualityOption {
        get { optionValue(in: Self.imageOptionsDescriptor, \.selectedQuality) }
        set { persistOutputAffectingOption(in: Self.imageOptionsDescriptor, \.selectedQuality, to: newValue) }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { optionValue(in: Self.imageOptionsDescriptor, \.selectedPNGCompressionLevel) }
        set { persistOutputAffectingOption(in: Self.imageOptionsDescriptor, \.selectedPNGCompressionLevel, to: newValue) }
    }

    var preserveImageAnimation: Bool {
        get { optionValue(in: Self.imageOptionsDescriptor, \.preserveAnimation) }
        set { persistOutputAffectingOption(in: Self.imageOptionsDescriptor, \.preserveAnimation, to: newValue) }
    }

    var selectedImageOutputDirectoryURL: URL? {
        get { optionValue(in: Self.imageOptionsDescriptor, \.selectedOutputDirectoryURL) }
        set { setOutputAffectingOption(in: Self.imageOptionsDescriptor, \.selectedOutputDirectoryURL, to: newValue) }
    }

    // Audio options
    var selectedAudioOutputFormat: AudioFormatOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputFormat) }
        set {
            deferOutputAffectingOption(
                in: Self.audioOptionsDescriptor,
                \.selectedOutputFormat,
                to: newValue,
                action: .audioFormatChange
            )
        }
    }

    var selectedAudioOutputEncoder: AudioEncoderOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputEncoder) }
        set {
            deferOutputAffectingOption(
                in: Self.audioOptionsDescriptor,
                \.selectedOutputEncoder,
                to: newValue,
                action: .audioOptionNormalization
            )
        }
    }

    var selectedAudioOutputMode: AudioModeOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputMode) }
        set { persistOutputAffectingOption(in: Self.audioOptionsDescriptor, \.selectedOutputMode, to: newValue) }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputSampleRate) }
        set { persistOutputAffectingOption(in: Self.audioOptionsDescriptor, \.selectedOutputSampleRate, to: newValue) }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputBitRate) }
        set { persistOutputAffectingOption(in: Self.audioOptionsDescriptor, \.selectedOutputBitRate, to: newValue) }
    }

    var selectedAudioOutputDirectoryURL: URL? {
        get { optionValue(in: Self.audioOptionsDescriptor, \.selectedOutputDirectoryURL) }
        set { setOutputAffectingOption(in: Self.audioOptionsDescriptor, \.selectedOutputDirectoryURL, to: newValue) }
    }
}
