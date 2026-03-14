import Foundation

extension ContentViewModel {
    private static let videoRuntimeStateDescriptor = StateProxyDescriptor(
        stateKeyPath: \.videoRuntimeState
    )

    private static let imageRuntimeStateDescriptor = StateProxyDescriptor(
        stateKeyPath: \.imageRuntimeState
    )

    private static let audioRuntimeStateDescriptor = StateProxyDescriptor(
        stateKeyPath: \.audioRuntimeState
    )

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
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.sourceURL) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.sourceURL, to: newValue) }
    }

    var queuedSourceURLs: [URL] {
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.queuedSourceURLs) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.queuedSourceURLs, to: newValue) }
    }

    var convertedURL: URL? {
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.convertedURL) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.convertedURL, to: newValue) }
    }

    var convertedURLs: [URL] {
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.convertedURLs) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.convertedURLs, to: newValue) }
    }

    var convertedOutputURLsBySourceID: [String: URL] {
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.convertedOutputURLsBySourceID) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedSourceIDs: Set<String> {
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.processedSourceIDs) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.processedSourceIDs, to: newValue) }
    }

    var isAnalyzingSource: Bool {
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.isAnalyzingSource) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.isAnalyzingSource, to: newValue) }
    }

    var isConverting: Bool {
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.isConverting) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.isConverting, to: newValue) }
    }

    var conversionProgress: Double {
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.conversionProgress) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.conversionProgress, to: newValue) }
    }

    var availableOutputFormats: [VideoFormatOption] {
        get { mediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.availableOutputFormats) }
        set { setMediaRuntimeValue(using: Self.videoRuntimeStateDescriptor, \.availableOutputFormats, to: newValue) }
    }

    // Image state
    var imageSourceURL: URL? {
        get { mediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.sourceURL) }
        set { setMediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.sourceURL, to: newValue) }
    }

    var queuedImageSourceURLs: [URL] {
        get { mediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.queuedSourceURLs) }
        set { setMediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.queuedSourceURLs, to: newValue) }
    }

    var convertedImageURL: URL? {
        get { mediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.convertedURL) }
        set { setMediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.convertedURL, to: newValue) }
    }

    var convertedImageURLs: [URL] {
        get { mediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.convertedURLs) }
        set { setMediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.convertedURLs, to: newValue) }
    }

    var convertedImageOutputURLsBySourceID: [String: URL] {
        get { mediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.convertedOutputURLsBySourceID) }
        set { setMediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedImageSourceIDs: Set<String> {
        get { mediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.processedSourceIDs) }
        set { setMediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.processedSourceIDs, to: newValue) }
    }

    var isAnalyzingImageSource: Bool {
        get { mediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.isAnalyzingSource) }
        set { setMediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.isAnalyzingSource, to: newValue) }
    }

    var isImageConverting: Bool {
        get { mediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.isConverting) }
        set { setMediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.isConverting, to: newValue) }
    }

    var imageConversionProgress: Double {
        get { mediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.conversionProgress) }
        set { setMediaRuntimeValue(using: Self.imageRuntimeStateDescriptor, \.conversionProgress, to: newValue) }
    }

    // Audio state
    var audioSourceURL: URL? {
        get { mediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.sourceURL) }
        set { setMediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.sourceURL, to: newValue) }
    }

    var queuedAudioSourceURLs: [URL] {
        get { mediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.queuedSourceURLs) }
        set { setMediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.queuedSourceURLs, to: newValue) }
    }

    var convertedAudioURL: URL? {
        get { mediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.convertedURL) }
        set { setMediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.convertedURL, to: newValue) }
    }

    var convertedAudioURLs: [URL] {
        get { mediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.convertedURLs) }
        set { setMediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.convertedURLs, to: newValue) }
    }

    var convertedAudioOutputURLsBySourceID: [String: URL] {
        get { mediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.convertedOutputURLsBySourceID) }
        set { setMediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedAudioSourceIDs: Set<String> {
        get { mediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.processedSourceIDs) }
        set { setMediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.processedSourceIDs, to: newValue) }
    }

    var isAnalyzingAudioSource: Bool {
        get { mediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.isAnalyzingSource) }
        set { setMediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.isAnalyzingSource, to: newValue) }
    }

    var isAudioConverting: Bool {
        get { mediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.isConverting) }
        set { setMediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.isConverting, to: newValue) }
    }

    var audioConversionProgress: Double {
        get { mediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.conversionProgress) }
        set { setMediaRuntimeValue(using: Self.audioRuntimeStateDescriptor, \.conversionProgress, to: newValue) }
    }

}
