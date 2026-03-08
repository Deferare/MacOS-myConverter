import Foundation

extension ContentViewModel {
    private typealias VideoOptionsStateKeyPath = ReferenceWritableKeyPath<ContentViewModel, VideoOptionsState>
    private typealias ImageOptionsStateKeyPath = ReferenceWritableKeyPath<ContentViewModel, ImageOptionsState>
    private typealias AudioOptionsStateKeyPath = ReferenceWritableKeyPath<ContentViewModel, AudioOptionsState>

    private struct OptionStateDescriptor<State> {
        let stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>
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
        OptionStateDescriptor(stateKeyPath: \.videoOptionsState, persistKind: .video)
    }

    private var imageOptionsDescriptor: OptionStateDescriptor<ImageOptionsState> {
        OptionStateDescriptor(stateKeyPath: \.imageOptionsState, persistKind: .image)
    }

    private var audioOptionsDescriptor: OptionStateDescriptor<AudioOptionsState> {
        OptionStateDescriptor(stateKeyPath: \.audioOptionsState, persistKind: .audio)
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

    private func persistOption<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value
    ) {
        persistOption(in: descriptor.stateKeyPath, valueKeyPath, to: newValue, for: descriptor.persistKind)
    }

    private func deferOption<State, Value: Equatable>(
        in descriptor: OptionStateDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        action: DeferredPersistenceAction
    ) {
        deferOption(in: descriptor.stateKeyPath, valueKeyPath, to: newValue, action: action)
    }

    // Video options
    var selectedOutputFormat: VideoFormatOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedOutputFormat) }
        set { deferOption(in: videoOptionsDescriptor, \.selectedOutputFormat, to: newValue, action: .videoFormatChange) }
    }

    var selectedVideoEncoder: VideoEncoderOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedVideoEncoder) }
        set { deferOption(in: videoOptionsDescriptor, \.selectedVideoEncoder, to: newValue, action: .videoOptionNormalization) }
    }

    var selectedResolution: ResolutionOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedResolution) }
        set { persistOption(in: videoOptionsDescriptor, \.selectedResolution, to: newValue) }
    }

    var selectedFrameRate: FrameRateOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedFrameRate) }
        set { persistOption(in: videoOptionsDescriptor, \.selectedFrameRate, to: newValue) }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedGIFPlaybackSpeed) }
        set { persistOption(in: videoOptionsDescriptor, \.selectedGIFPlaybackSpeed, to: newValue) }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedVideoBitRate) }
        set { persistOption(in: videoOptionsDescriptor, \.selectedVideoBitRate, to: newValue) }
    }

    var customVideoBitRate: String {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.customVideoBitRate) }
        set { persistOption(in: videoOptionsDescriptor, \.customVideoBitRate, to: newValue) }
    }

    var selectedAudioEncoder: AudioEncoderOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedAudioEncoder) }
        set { deferOption(in: videoOptionsDescriptor, \.selectedAudioEncoder, to: newValue, action: .videoOptionNormalization) }
    }

    var selectedAudioMode: AudioModeOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedAudioMode) }
        set { persistOption(in: videoOptionsDescriptor, \.selectedAudioMode, to: newValue) }
    }

    var selectedSampleRate: SampleRateOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedSampleRate) }
        set { persistOption(in: videoOptionsDescriptor, \.selectedSampleRate, to: newValue) }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { optionValue(in: videoOptionsDescriptor.stateKeyPath, \.selectedAudioBitRate) }
        set { persistOption(in: videoOptionsDescriptor, \.selectedAudioBitRate, to: newValue) }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { optionValue(in: imageOptionsDescriptor.stateKeyPath, \.selectedOutputFormat) }
        set { persistOption(in: imageOptionsDescriptor, \.selectedOutputFormat, to: newValue) }
    }

    var selectedImageResolution: ResolutionOption {
        get { optionValue(in: imageOptionsDescriptor.stateKeyPath, \.selectedResolution) }
        set { persistOption(in: imageOptionsDescriptor, \.selectedResolution, to: newValue) }
    }

    var selectedImageQuality: ImageQualityOption {
        get { optionValue(in: imageOptionsDescriptor.stateKeyPath, \.selectedQuality) }
        set { persistOption(in: imageOptionsDescriptor, \.selectedQuality, to: newValue) }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { optionValue(in: imageOptionsDescriptor.stateKeyPath, \.selectedPNGCompressionLevel) }
        set { persistOption(in: imageOptionsDescriptor, \.selectedPNGCompressionLevel, to: newValue) }
    }

    var preserveImageAnimation: Bool {
        get { optionValue(in: imageOptionsDescriptor.stateKeyPath, \.preserveAnimation) }
        set { persistOption(in: imageOptionsDescriptor, \.preserveAnimation, to: newValue) }
    }

    // Audio options
    var selectedAudioOutputFormat: AudioFormatOption {
        get { optionValue(in: audioOptionsDescriptor.stateKeyPath, \.selectedOutputFormat) }
        set { deferOption(in: audioOptionsDescriptor, \.selectedOutputFormat, to: newValue, action: .audioFormatChange) }
    }

    var selectedAudioOutputEncoder: AudioEncoderOption {
        get { optionValue(in: audioOptionsDescriptor.stateKeyPath, \.selectedOutputEncoder) }
        set { deferOption(in: audioOptionsDescriptor, \.selectedOutputEncoder, to: newValue, action: .audioOptionNormalization) }
    }

    var selectedAudioOutputMode: AudioModeOption {
        get { optionValue(in: audioOptionsDescriptor.stateKeyPath, \.selectedOutputMode) }
        set { persistOption(in: audioOptionsDescriptor, \.selectedOutputMode, to: newValue) }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { optionValue(in: audioOptionsDescriptor.stateKeyPath, \.selectedOutputSampleRate) }
        set { persistOption(in: audioOptionsDescriptor, \.selectedOutputSampleRate, to: newValue) }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { optionValue(in: audioOptionsDescriptor.stateKeyPath, \.selectedOutputBitRate) }
        set { persistOption(in: audioOptionsDescriptor, \.selectedOutputBitRate, to: newValue) }
    }
}
