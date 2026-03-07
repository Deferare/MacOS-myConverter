import Foundation

extension ContentViewModel {
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

    private func persistOption<State, Value: Equatable>(
        in stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        for kind: MediaKind
    ) {
        setOptionValue(in: stateKeyPath, valueKeyPath, to: newValue) {
            self.persistCurrentSourceSettingsIfNeeded(for: kind)
        }
    }

    private func deferOption<State, Value: Equatable>(
        in stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value,
        action: DeferredPersistenceAction
    ) {
        setOptionValue(in: stateKeyPath, valueKeyPath, to: newValue) {
            self.scheduleDeferredPersistenceAction(action)
        }
    }

    private func videoOptionValue<Value>(_ keyPath: KeyPath<VideoOptionsState, Value>) -> Value {
        optionValue(in: \.videoOptionsState, keyPath)
    }

    private func persistVideoOption<Value: Equatable>(
        _ keyPath: WritableKeyPath<VideoOptionsState, Value>,
        to newValue: Value
    ) {
        persistOption(in: \.videoOptionsState, keyPath, to: newValue, for: .video)
    }

    private func deferVideoOption<Value: Equatable>(
        _ keyPath: WritableKeyPath<VideoOptionsState, Value>,
        to newValue: Value,
        action: DeferredPersistenceAction
    ) {
        deferOption(in: \.videoOptionsState, keyPath, to: newValue, action: action)
    }

    private func imageOptionValue<Value>(_ keyPath: KeyPath<ImageOptionsState, Value>) -> Value {
        optionValue(in: \.imageOptionsState, keyPath)
    }

    private func persistImageOption<Value: Equatable>(
        _ keyPath: WritableKeyPath<ImageOptionsState, Value>,
        to newValue: Value
    ) {
        persistOption(in: \.imageOptionsState, keyPath, to: newValue, for: .image)
    }

    private func audioOptionValue<Value>(_ keyPath: KeyPath<AudioOptionsState, Value>) -> Value {
        optionValue(in: \.audioOptionsState, keyPath)
    }

    private func persistAudioOption<Value: Equatable>(
        _ keyPath: WritableKeyPath<AudioOptionsState, Value>,
        to newValue: Value
    ) {
        persistOption(in: \.audioOptionsState, keyPath, to: newValue, for: .audio)
    }

    private func deferAudioOption<Value: Equatable>(
        _ keyPath: WritableKeyPath<AudioOptionsState, Value>,
        to newValue: Value,
        action: DeferredPersistenceAction
    ) {
        deferOption(in: \.audioOptionsState, keyPath, to: newValue, action: action)
    }

    // Video options
    var selectedOutputFormat: VideoFormatOption {
        get { videoOptionValue(\.selectedOutputFormat) }
        set { deferVideoOption(\.selectedOutputFormat, to: newValue, action: .videoFormatChange) }
    }

    var selectedVideoEncoder: VideoEncoderOption {
        get { videoOptionValue(\.selectedVideoEncoder) }
        set { deferVideoOption(\.selectedVideoEncoder, to: newValue, action: .videoOptionNormalization) }
    }

    var selectedResolution: ResolutionOption {
        get { videoOptionValue(\.selectedResolution) }
        set { persistVideoOption(\.selectedResolution, to: newValue) }
    }

    var selectedFrameRate: FrameRateOption {
        get { videoOptionValue(\.selectedFrameRate) }
        set { persistVideoOption(\.selectedFrameRate, to: newValue) }
    }

    var selectedGIFPlaybackSpeed: GIFPlaybackSpeedOption {
        get { videoOptionValue(\.selectedGIFPlaybackSpeed) }
        set { persistVideoOption(\.selectedGIFPlaybackSpeed, to: newValue) }
    }

    var selectedVideoBitRate: VideoBitRateOption {
        get { videoOptionValue(\.selectedVideoBitRate) }
        set { persistVideoOption(\.selectedVideoBitRate, to: newValue) }
    }

    var customVideoBitRate: String {
        get { videoOptionValue(\.customVideoBitRate) }
        set { persistVideoOption(\.customVideoBitRate, to: newValue) }
    }

    var selectedAudioEncoder: AudioEncoderOption {
        get { videoOptionValue(\.selectedAudioEncoder) }
        set { deferVideoOption(\.selectedAudioEncoder, to: newValue, action: .videoOptionNormalization) }
    }

    var selectedAudioMode: AudioModeOption {
        get { videoOptionValue(\.selectedAudioMode) }
        set { persistVideoOption(\.selectedAudioMode, to: newValue) }
    }

    var selectedSampleRate: SampleRateOption {
        get { videoOptionValue(\.selectedSampleRate) }
        set { persistVideoOption(\.selectedSampleRate, to: newValue) }
    }

    var selectedAudioBitRate: AudioBitRateOption {
        get { videoOptionValue(\.selectedAudioBitRate) }
        set { persistVideoOption(\.selectedAudioBitRate, to: newValue) }
    }

    // Image options
    var selectedImageOutputFormat: ImageFormatOption {
        get { imageOptionValue(\.selectedOutputFormat) }
        set { persistImageOption(\.selectedOutputFormat, to: newValue) }
    }

    var selectedImageResolution: ResolutionOption {
        get { imageOptionValue(\.selectedResolution) }
        set { persistImageOption(\.selectedResolution, to: newValue) }
    }

    var selectedImageQuality: ImageQualityOption {
        get { imageOptionValue(\.selectedQuality) }
        set { persistImageOption(\.selectedQuality, to: newValue) }
    }

    var selectedPNGCompressionLevel: PNGCompressionLevelOption {
        get { imageOptionValue(\.selectedPNGCompressionLevel) }
        set { persistImageOption(\.selectedPNGCompressionLevel, to: newValue) }
    }

    var preserveImageAnimation: Bool {
        get { imageOptionValue(\.preserveAnimation) }
        set { persistImageOption(\.preserveAnimation, to: newValue) }
    }

    // Audio options
    var selectedAudioOutputFormat: AudioFormatOption {
        get { audioOptionValue(\.selectedOutputFormat) }
        set { deferAudioOption(\.selectedOutputFormat, to: newValue, action: .audioFormatChange) }
    }

    var selectedAudioOutputEncoder: AudioEncoderOption {
        get { audioOptionValue(\.selectedOutputEncoder) }
        set { deferAudioOption(\.selectedOutputEncoder, to: newValue, action: .audioOptionNormalization) }
    }

    var selectedAudioOutputMode: AudioModeOption {
        get { audioOptionValue(\.selectedOutputMode) }
        set { persistAudioOption(\.selectedOutputMode, to: newValue) }
    }

    var selectedAudioOutputSampleRate: SampleRateOption {
        get { audioOptionValue(\.selectedOutputSampleRate) }
        set { persistAudioOption(\.selectedOutputSampleRate, to: newValue) }
    }

    var selectedAudioOutputBitRate: AudioBitRateOption {
        get { audioOptionValue(\.selectedOutputBitRate) }
        set { persistAudioOption(\.selectedOutputBitRate, to: newValue) }
    }
}
