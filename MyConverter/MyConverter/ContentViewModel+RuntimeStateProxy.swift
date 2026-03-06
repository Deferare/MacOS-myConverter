import Foundation

extension ContentViewModel {
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

    private func videoRuntimeValue<Value>(_ keyPath: KeyPath<VideoRuntimeState, Value>) -> Value {
        runtimeValue(in: \.videoRuntimeState, keyPath)
    }

    private func setVideoRuntimeValue<Value: Equatable>(
        _ keyPath: WritableKeyPath<VideoRuntimeState, Value>,
        to newValue: Value
    ) {
        setRuntimeValue(in: \.videoRuntimeState, keyPath, to: newValue)
    }

    private func imageRuntimeValue<Value>(_ keyPath: KeyPath<ImageRuntimeState, Value>) -> Value {
        runtimeValue(in: \.imageRuntimeState, keyPath)
    }

    private func setImageRuntimeValue<Value: Equatable>(
        _ keyPath: WritableKeyPath<ImageRuntimeState, Value>,
        to newValue: Value
    ) {
        setRuntimeValue(in: \.imageRuntimeState, keyPath, to: newValue)
    }

    private func audioRuntimeValue<Value>(_ keyPath: KeyPath<AudioRuntimeState, Value>) -> Value {
        runtimeValue(in: \.audioRuntimeState, keyPath)
    }

    private func setAudioRuntimeValue<Value: Equatable>(
        _ keyPath: WritableKeyPath<AudioRuntimeState, Value>,
        to newValue: Value
    ) {
        setRuntimeValue(in: \.audioRuntimeState, keyPath, to: newValue)
    }

    // Video state
    var sourceURL: URL? {
        get { videoRuntimeValue(\.sourceURL) }
        set { setVideoRuntimeValue(\.sourceURL, to: newValue) }
    }

    var queuedSourceURLs: [URL] {
        get { videoRuntimeValue(\.queuedSourceURLs) }
        set { setVideoRuntimeValue(\.queuedSourceURLs, to: newValue) }
    }

    var convertedURL: URL? {
        get { videoRuntimeValue(\.convertedURL) }
        set { setVideoRuntimeValue(\.convertedURL, to: newValue) }
    }

    var convertedURLs: [URL] {
        get { videoRuntimeValue(\.convertedURLs) }
        set { setVideoRuntimeValue(\.convertedURLs, to: newValue) }
    }

    var conversionErrorMessage: String? {
        get { videoRuntimeValue(\.conversionErrorMessage) }
        set { setVideoRuntimeValue(\.conversionErrorMessage, to: newValue) }
    }

    var sourceCompatibilityErrorMessage: String? {
        get { videoRuntimeValue(\.sourceCompatibilityErrorMessage) }
        set { setVideoRuntimeValue(\.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var sourceCompatibilityWarningMessage: String? {
        get { videoRuntimeValue(\.sourceCompatibilityWarningMessage) }
        set { setVideoRuntimeValue(\.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingSource: Bool {
        get { videoRuntimeValue(\.isAnalyzingSource) }
        set { setVideoRuntimeValue(\.isAnalyzingSource, to: newValue) }
    }

    var isConverting: Bool {
        get { videoRuntimeValue(\.isConverting) }
        set { setVideoRuntimeValue(\.isConverting, to: newValue) }
    }

    var conversionProgress: Double {
        get { videoRuntimeValue(\.conversionProgress) }
        set { setVideoRuntimeValue(\.conversionProgress, to: newValue) }
    }

    var currentVideoBatchIndex: Int {
        get { videoRuntimeValue(\.currentBatchIndex) }
        set { setVideoRuntimeValue(\.currentBatchIndex, to: newValue) }
    }

    var totalVideoBatchCount: Int {
        get { videoRuntimeValue(\.totalBatchCount) }
        set { setVideoRuntimeValue(\.totalBatchCount, to: newValue) }
    }

    var availableOutputFormats: [VideoFormatOption] {
        get { videoRuntimeValue(\.availableOutputFormats) }
        set { setVideoRuntimeValue(\.availableOutputFormats, to: newValue) }
    }

    var availableVideoEncoders: [VideoEncoderOption] {
        get { videoRuntimeValue(\.availableVideoEncoders) }
        set { setVideoRuntimeValue(\.availableVideoEncoders, to: newValue) }
    }

    var availableAudioEncoders: [AudioEncoderOption] {
        get { videoRuntimeValue(\.availableAudioEncoders) }
        set { setVideoRuntimeValue(\.availableAudioEncoders, to: newValue) }
    }

    // Image state
    var imageSourceURL: URL? {
        get { imageRuntimeValue(\.sourceURL) }
        set { setImageRuntimeValue(\.sourceURL, to: newValue) }
    }

    var queuedImageSourceURLs: [URL] {
        get { imageRuntimeValue(\.queuedSourceURLs) }
        set { setImageRuntimeValue(\.queuedSourceURLs, to: newValue) }
    }

    var convertedImageURL: URL? {
        get { imageRuntimeValue(\.convertedURL) }
        set { setImageRuntimeValue(\.convertedURL, to: newValue) }
    }

    var convertedImageURLs: [URL] {
        get { imageRuntimeValue(\.convertedURLs) }
        set { setImageRuntimeValue(\.convertedURLs, to: newValue) }
    }

    var imageConversionErrorMessage: String? {
        get { imageRuntimeValue(\.conversionErrorMessage) }
        set { setImageRuntimeValue(\.conversionErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityErrorMessage: String? {
        get { imageRuntimeValue(\.sourceCompatibilityErrorMessage) }
        set { setImageRuntimeValue(\.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityWarningMessage: String? {
        get { imageRuntimeValue(\.sourceCompatibilityWarningMessage) }
        set { setImageRuntimeValue(\.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingImageSource: Bool {
        get { imageRuntimeValue(\.isAnalyzingSource) }
        set { setImageRuntimeValue(\.isAnalyzingSource, to: newValue) }
    }

    var imageSourceFrameCount: Int {
        get { imageRuntimeValue(\.sourceFrameCount) }
        set { setImageRuntimeValue(\.sourceFrameCount, to: newValue) }
    }

    var imageSourceHasAlpha: Bool {
        get { imageRuntimeValue(\.sourceHasAlpha) }
        set { setImageRuntimeValue(\.sourceHasAlpha, to: newValue) }
    }

    var isImageConverting: Bool {
        get { imageRuntimeValue(\.isConverting) }
        set { setImageRuntimeValue(\.isConverting, to: newValue) }
    }

    var imageConversionProgress: Double {
        get { imageRuntimeValue(\.conversionProgress) }
        set { setImageRuntimeValue(\.conversionProgress, to: newValue) }
    }

    var currentImageBatchIndex: Int {
        get { imageRuntimeValue(\.currentBatchIndex) }
        set { setImageRuntimeValue(\.currentBatchIndex, to: newValue) }
    }

    var totalImageBatchCount: Int {
        get { imageRuntimeValue(\.totalBatchCount) }
        set { setImageRuntimeValue(\.totalBatchCount, to: newValue) }
    }

    var availableImageOutputFormats: [ImageFormatOption] {
        get { imageRuntimeValue(\.availableOutputFormats) }
        set { setImageRuntimeValue(\.availableOutputFormats, to: newValue) }
    }

    // Audio state
    var audioSourceURL: URL? {
        get { audioRuntimeValue(\.sourceURL) }
        set { setAudioRuntimeValue(\.sourceURL, to: newValue) }
    }

    var queuedAudioSourceURLs: [URL] {
        get { audioRuntimeValue(\.queuedSourceURLs) }
        set { setAudioRuntimeValue(\.queuedSourceURLs, to: newValue) }
    }

    var convertedAudioURL: URL? {
        get { audioRuntimeValue(\.convertedURL) }
        set { setAudioRuntimeValue(\.convertedURL, to: newValue) }
    }

    var convertedAudioURLs: [URL] {
        get { audioRuntimeValue(\.convertedURLs) }
        set { setAudioRuntimeValue(\.convertedURLs, to: newValue) }
    }

    var audioConversionErrorMessage: String? {
        get { audioRuntimeValue(\.conversionErrorMessage) }
        set { setAudioRuntimeValue(\.conversionErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityErrorMessage: String? {
        get { audioRuntimeValue(\.sourceCompatibilityErrorMessage) }
        set { setAudioRuntimeValue(\.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityWarningMessage: String? {
        get { audioRuntimeValue(\.sourceCompatibilityWarningMessage) }
        set { setAudioRuntimeValue(\.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingAudioSource: Bool {
        get { audioRuntimeValue(\.isAnalyzingSource) }
        set { setAudioRuntimeValue(\.isAnalyzingSource, to: newValue) }
    }

    var isAudioConverting: Bool {
        get { audioRuntimeValue(\.isConverting) }
        set { setAudioRuntimeValue(\.isConverting, to: newValue) }
    }

    var audioConversionProgress: Double {
        get { audioRuntimeValue(\.conversionProgress) }
        set { setAudioRuntimeValue(\.conversionProgress, to: newValue) }
    }

    var currentAudioBatchIndex: Int {
        get { audioRuntimeValue(\.currentBatchIndex) }
        set { setAudioRuntimeValue(\.currentBatchIndex, to: newValue) }
    }

    var totalAudioBatchCount: Int {
        get { audioRuntimeValue(\.totalBatchCount) }
        set { setAudioRuntimeValue(\.totalBatchCount, to: newValue) }
    }

    var availableAudioOutputFormats: [AudioFormatOption] {
        get { audioRuntimeValue(\.availableOutputFormats) }
        set { setAudioRuntimeValue(\.availableOutputFormats, to: newValue) }
    }

    var availableAudioOutputEncoders: [AudioEncoderOption] {
        get { audioRuntimeValue(\.availableOutputEncoders) }
        set { setAudioRuntimeValue(\.availableOutputEncoders, to: newValue) }
    }
}
