import Foundation

extension ContentViewModel {
    private var videoRuntimeStateDescriptor: StateProxyDescriptor<VideoRuntimeState> {
        StateProxyDescriptor(stateKeyPath: \.videoRuntimeState)
    }

    private var imageRuntimeStateDescriptor: StateProxyDescriptor<ImageRuntimeState> {
        StateProxyDescriptor(stateKeyPath: \.imageRuntimeState)
    }

    private var audioRuntimeStateDescriptor: StateProxyDescriptor<AudioRuntimeState> {
        StateProxyDescriptor(stateKeyPath: \.audioRuntimeState)
    }

    private func runtimeValue<State, Value>(
        using descriptor: StateProxyDescriptor<State>,
        _ valueKeyPath: KeyPath<State, Value>
    ) -> Value {
        stateValue(using: descriptor, at: valueKeyPath)
    }

    private func setRuntimeValue<State, Value: Equatable>(
        using descriptor: StateProxyDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<State, Value>,
        to newValue: Value
    ) {
        updateState(using: descriptor, value: valueKeyPath, to: newValue)
    }

    private func mediaRuntimeValue<State: MediaRuntimeStateContainer, Value>(
        using descriptor: StateProxyDescriptor<State>,
        _ valueKeyPath: KeyPath<MediaRuntimeState<State.Format>, Value>
    ) -> Value {
        self[keyPath: descriptor.stateKeyPath].media[keyPath: valueKeyPath]
    }

    private func setMediaRuntimeValue<State: MediaRuntimeStateContainer, Value: Equatable>(
        using descriptor: StateProxyDescriptor<State>,
        _ valueKeyPath: WritableKeyPath<MediaRuntimeState<State.Format>, Value>,
        to newValue: Value
    ) {
        var state = self[keyPath: descriptor.stateKeyPath]
        guard state.media[keyPath: valueKeyPath] != newValue else { return }
        state.media[keyPath: valueKeyPath] = newValue
        self[keyPath: descriptor.stateKeyPath] = state
    }

    // Video state
    var sourceURL: URL? {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.sourceURL) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.sourceURL, to: newValue) }
    }

    var queuedSourceURLs: [URL] {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.queuedSourceURLs) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.queuedSourceURLs, to: newValue) }
    }

    var convertedURL: URL? {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.convertedURL) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.convertedURL, to: newValue) }
    }

    var convertedURLs: [URL] {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.convertedURLs) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.convertedURLs, to: newValue) }
    }

    var convertedOutputURLsBySourceID: [String: URL] {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.convertedOutputURLsBySourceID) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedSourceIDs: Set<String> {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.processedSourceIDs) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.processedSourceIDs, to: newValue) }
    }

    var conversionErrorMessage: String? {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.conversionErrorMessage) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.conversionErrorMessage, to: newValue) }
    }

    var sourceCompatibilityErrorMessage: String? {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.sourceCompatibilityErrorMessage) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var sourceCompatibilityWarningMessage: String? {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.sourceCompatibilityWarningMessage) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingSource: Bool {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.isAnalyzingSource) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.isAnalyzingSource, to: newValue) }
    }

    var isConverting: Bool {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.isConverting) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.isConverting, to: newValue) }
    }

    var conversionProgress: Double {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.conversionProgress) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.conversionProgress, to: newValue) }
    }

    var currentVideoBatchIndex: Int {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.currentBatchIndex) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.currentBatchIndex, to: newValue) }
    }

    var totalVideoBatchCount: Int {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.totalBatchCount) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.totalBatchCount, to: newValue) }
    }

    var availableOutputFormats: [VideoFormatOption] {
        get { mediaRuntimeValue(using: videoRuntimeStateDescriptor, \.availableOutputFormats) }
        set { setMediaRuntimeValue(using: videoRuntimeStateDescriptor, \.availableOutputFormats, to: newValue) }
    }

    var availableVideoEncoders: [VideoEncoderOption] {
        get { runtimeValue(using: videoRuntimeStateDescriptor, \.availableVideoEncoders) }
        set { setRuntimeValue(using: videoRuntimeStateDescriptor, \.availableVideoEncoders, to: newValue) }
    }

    var availableAudioEncoders: [AudioEncoderOption] {
        get { runtimeValue(using: videoRuntimeStateDescriptor, \.availableAudioEncoders) }
        set { setRuntimeValue(using: videoRuntimeStateDescriptor, \.availableAudioEncoders, to: newValue) }
    }

    // Image state
    var imageSourceURL: URL? {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.sourceURL) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.sourceURL, to: newValue) }
    }

    var queuedImageSourceURLs: [URL] {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.queuedSourceURLs) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.queuedSourceURLs, to: newValue) }
    }

    var convertedImageURL: URL? {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.convertedURL) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.convertedURL, to: newValue) }
    }

    var convertedImageURLs: [URL] {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.convertedURLs) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.convertedURLs, to: newValue) }
    }

    var convertedImageOutputURLsBySourceID: [String: URL] {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.convertedOutputURLsBySourceID) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedImageSourceIDs: Set<String> {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.processedSourceIDs) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.processedSourceIDs, to: newValue) }
    }

    var imageConversionErrorMessage: String? {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.conversionErrorMessage) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.conversionErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityErrorMessage: String? {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.sourceCompatibilityErrorMessage) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityWarningMessage: String? {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.sourceCompatibilityWarningMessage) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingImageSource: Bool {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.isAnalyzingSource) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.isAnalyzingSource, to: newValue) }
    }

    var imageSourceFrameCount: Int {
        get { runtimeValue(using: imageRuntimeStateDescriptor, \.sourceFrameCount) }
        set { setRuntimeValue(using: imageRuntimeStateDescriptor, \.sourceFrameCount, to: newValue) }
    }

    var imageSourceHasAlpha: Bool {
        get { runtimeValue(using: imageRuntimeStateDescriptor, \.sourceHasAlpha) }
        set { setRuntimeValue(using: imageRuntimeStateDescriptor, \.sourceHasAlpha, to: newValue) }
    }

    var isImageConverting: Bool {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.isConverting) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.isConverting, to: newValue) }
    }

    var imageConversionProgress: Double {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.conversionProgress) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.conversionProgress, to: newValue) }
    }

    var currentImageBatchIndex: Int {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.currentBatchIndex) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.currentBatchIndex, to: newValue) }
    }

    var totalImageBatchCount: Int {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.totalBatchCount) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.totalBatchCount, to: newValue) }
    }

    var availableImageOutputFormats: [ImageFormatOption] {
        get { mediaRuntimeValue(using: imageRuntimeStateDescriptor, \.availableOutputFormats) }
        set { setMediaRuntimeValue(using: imageRuntimeStateDescriptor, \.availableOutputFormats, to: newValue) }
    }

    // Audio state
    var audioSourceURL: URL? {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.sourceURL) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.sourceURL, to: newValue) }
    }

    var queuedAudioSourceURLs: [URL] {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.queuedSourceURLs) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.queuedSourceURLs, to: newValue) }
    }

    var convertedAudioURL: URL? {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.convertedURL) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.convertedURL, to: newValue) }
    }

    var convertedAudioURLs: [URL] {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.convertedURLs) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.convertedURLs, to: newValue) }
    }

    var convertedAudioOutputURLsBySourceID: [String: URL] {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.convertedOutputURLsBySourceID) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedAudioSourceIDs: Set<String> {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.processedSourceIDs) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.processedSourceIDs, to: newValue) }
    }

    var audioConversionErrorMessage: String? {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.conversionErrorMessage) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.conversionErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityErrorMessage: String? {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.sourceCompatibilityErrorMessage) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityWarningMessage: String? {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.sourceCompatibilityWarningMessage) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingAudioSource: Bool {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.isAnalyzingSource) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.isAnalyzingSource, to: newValue) }
    }

    var isAudioConverting: Bool {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.isConverting) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.isConverting, to: newValue) }
    }

    var audioConversionProgress: Double {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.conversionProgress) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.conversionProgress, to: newValue) }
    }

    var currentAudioBatchIndex: Int {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.currentBatchIndex) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.currentBatchIndex, to: newValue) }
    }

    var totalAudioBatchCount: Int {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.totalBatchCount) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.totalBatchCount, to: newValue) }
    }

    var availableAudioOutputFormats: [AudioFormatOption] {
        get { mediaRuntimeValue(using: audioRuntimeStateDescriptor, \.availableOutputFormats) }
        set { setMediaRuntimeValue(using: audioRuntimeStateDescriptor, \.availableOutputFormats, to: newValue) }
    }

    var availableAudioOutputEncoders: [AudioEncoderOption] {
        get { runtimeValue(using: audioRuntimeStateDescriptor, \.availableOutputEncoders) }
        set { setRuntimeValue(using: audioRuntimeStateDescriptor, \.availableOutputEncoders, to: newValue) }
    }
}
