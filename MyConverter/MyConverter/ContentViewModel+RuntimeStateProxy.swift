import Foundation

extension ContentViewModel {
    private typealias VideoRuntimeStateKeyPath = ReferenceWritableKeyPath<ContentViewModel, VideoRuntimeState>
    private typealias ImageRuntimeStateKeyPath = ReferenceWritableKeyPath<ContentViewModel, ImageRuntimeState>
    private typealias AudioRuntimeStateKeyPath = ReferenceWritableKeyPath<ContentViewModel, AudioRuntimeState>

    private var videoRuntimeStateKeyPath: VideoRuntimeStateKeyPath { \.videoRuntimeState }
    private var imageRuntimeStateKeyPath: ImageRuntimeStateKeyPath { \.imageRuntimeState }
    private var audioRuntimeStateKeyPath: AudioRuntimeStateKeyPath { \.audioRuntimeState }

    private func runtimeValue<State, Value>(
        in stateKeyPath: KeyPath<ContentViewModel, State>,
        _ valueKeyPath: KeyPath<State, Value>
    ) -> Value {
        stateValue(in: stateKeyPath, at: valueKeyPath)
    }

    private func setRuntimeValue<State, Value: Equatable>(
        in stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value
    ) {
        updateState(stateKeyPath, value: valueKeyPath, to: newValue)
    }

    private func mediaRuntimeValue<State: MediaRuntimeStateContainer, Value>(
        in stateKeyPath: KeyPath<ContentViewModel, State>,
        _ valueKeyPath: KeyPath<MediaRuntimeState<State.Format>, Value>
    ) -> Value {
        self[keyPath: stateKeyPath].media[keyPath: valueKeyPath]
    }

    private func setMediaRuntimeValue<State: MediaRuntimeStateContainer, Value: Equatable>(
        in stateKeyPath: ReferenceWritableKeyPath<ContentViewModel, State>,
        _ valueKeyPath: WritableKeyPath<MediaRuntimeState<State.Format>, Value>,
        to newValue: Value
    ) {
        var state = self[keyPath: stateKeyPath]
        guard state.media[keyPath: valueKeyPath] != newValue else { return }
        state.media[keyPath: valueKeyPath] = newValue
        self[keyPath: stateKeyPath] = state
    }

    // Video state
    var sourceURL: URL? {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.sourceURL) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.sourceURL, to: newValue) }
    }

    var queuedSourceURLs: [URL] {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.queuedSourceURLs) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.queuedSourceURLs, to: newValue) }
    }

    var convertedURL: URL? {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.convertedURL) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.convertedURL, to: newValue) }
    }

    var convertedURLs: [URL] {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.convertedURLs) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.convertedURLs, to: newValue) }
    }

    var convertedOutputURLsBySourceID: [String: URL] {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.convertedOutputURLsBySourceID) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedSourceIDs: Set<String> {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.processedSourceIDs) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.processedSourceIDs, to: newValue) }
    }

    var conversionErrorMessage: String? {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.conversionErrorMessage) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.conversionErrorMessage, to: newValue) }
    }

    var sourceCompatibilityErrorMessage: String? {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.sourceCompatibilityErrorMessage) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var sourceCompatibilityWarningMessage: String? {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.sourceCompatibilityWarningMessage) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingSource: Bool {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.isAnalyzingSource) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.isAnalyzingSource, to: newValue) }
    }

    var isConverting: Bool {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.isConverting) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.isConverting, to: newValue) }
    }

    var conversionProgress: Double {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.conversionProgress) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.conversionProgress, to: newValue) }
    }

    var currentVideoBatchIndex: Int {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.currentBatchIndex) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.currentBatchIndex, to: newValue) }
    }

    var totalVideoBatchCount: Int {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.totalBatchCount) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.totalBatchCount, to: newValue) }
    }

    var availableOutputFormats: [VideoFormatOption] {
        get { mediaRuntimeValue(in: videoRuntimeStateKeyPath, \.availableOutputFormats) }
        set { setMediaRuntimeValue(in: videoRuntimeStateKeyPath, \.availableOutputFormats, to: newValue) }
    }

    var availableVideoEncoders: [VideoEncoderOption] {
        get { runtimeValue(in: \.videoRuntimeState, \.availableVideoEncoders) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.availableVideoEncoders, to: newValue) }
    }

    var availableAudioEncoders: [AudioEncoderOption] {
        get { runtimeValue(in: \.videoRuntimeState, \.availableAudioEncoders) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.availableAudioEncoders, to: newValue) }
    }

    // Image state
    var imageSourceURL: URL? {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.sourceURL) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.sourceURL, to: newValue) }
    }

    var queuedImageSourceURLs: [URL] {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.queuedSourceURLs) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.queuedSourceURLs, to: newValue) }
    }

    var convertedImageURL: URL? {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.convertedURL) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.convertedURL, to: newValue) }
    }

    var convertedImageURLs: [URL] {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.convertedURLs) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.convertedURLs, to: newValue) }
    }

    var convertedImageOutputURLsBySourceID: [String: URL] {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.convertedOutputURLsBySourceID) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedImageSourceIDs: Set<String> {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.processedSourceIDs) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.processedSourceIDs, to: newValue) }
    }

    var imageConversionErrorMessage: String? {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.conversionErrorMessage) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.conversionErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityErrorMessage: String? {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.sourceCompatibilityErrorMessage) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityWarningMessage: String? {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.sourceCompatibilityWarningMessage) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingImageSource: Bool {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.isAnalyzingSource) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.isAnalyzingSource, to: newValue) }
    }

    var imageSourceFrameCount: Int {
        get { runtimeValue(in: \.imageRuntimeState, \.sourceFrameCount) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.sourceFrameCount, to: newValue) }
    }

    var imageSourceHasAlpha: Bool {
        get { runtimeValue(in: \.imageRuntimeState, \.sourceHasAlpha) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.sourceHasAlpha, to: newValue) }
    }

    var isImageConverting: Bool {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.isConverting) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.isConverting, to: newValue) }
    }

    var imageConversionProgress: Double {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.conversionProgress) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.conversionProgress, to: newValue) }
    }

    var currentImageBatchIndex: Int {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.currentBatchIndex) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.currentBatchIndex, to: newValue) }
    }

    var totalImageBatchCount: Int {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.totalBatchCount) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.totalBatchCount, to: newValue) }
    }

    var availableImageOutputFormats: [ImageFormatOption] {
        get { mediaRuntimeValue(in: imageRuntimeStateKeyPath, \.availableOutputFormats) }
        set { setMediaRuntimeValue(in: imageRuntimeStateKeyPath, \.availableOutputFormats, to: newValue) }
    }

    // Audio state
    var audioSourceURL: URL? {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.sourceURL) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.sourceURL, to: newValue) }
    }

    var queuedAudioSourceURLs: [URL] {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.queuedSourceURLs) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.queuedSourceURLs, to: newValue) }
    }

    var convertedAudioURL: URL? {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.convertedURL) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.convertedURL, to: newValue) }
    }

    var convertedAudioURLs: [URL] {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.convertedURLs) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.convertedURLs, to: newValue) }
    }

    var convertedAudioOutputURLsBySourceID: [String: URL] {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.convertedOutputURLsBySourceID) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedAudioSourceIDs: Set<String> {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.processedSourceIDs) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.processedSourceIDs, to: newValue) }
    }

    var audioConversionErrorMessage: String? {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.conversionErrorMessage) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.conversionErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityErrorMessage: String? {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.sourceCompatibilityErrorMessage) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityWarningMessage: String? {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.sourceCompatibilityWarningMessage) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingAudioSource: Bool {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.isAnalyzingSource) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.isAnalyzingSource, to: newValue) }
    }

    var isAudioConverting: Bool {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.isConverting) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.isConverting, to: newValue) }
    }

    var audioConversionProgress: Double {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.conversionProgress) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.conversionProgress, to: newValue) }
    }

    var currentAudioBatchIndex: Int {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.currentBatchIndex) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.currentBatchIndex, to: newValue) }
    }

    var totalAudioBatchCount: Int {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.totalBatchCount) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.totalBatchCount, to: newValue) }
    }

    var availableAudioOutputFormats: [AudioFormatOption] {
        get { mediaRuntimeValue(in: audioRuntimeStateKeyPath, \.availableOutputFormats) }
        set { setMediaRuntimeValue(in: audioRuntimeStateKeyPath, \.availableOutputFormats, to: newValue) }
    }

    var availableAudioOutputEncoders: [AudioEncoderOption] {
        get { runtimeValue(in: \.audioRuntimeState, \.availableOutputEncoders) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.availableOutputEncoders, to: newValue) }
    }
}
