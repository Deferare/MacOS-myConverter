import Foundation

extension ContentViewModel {
    // Video state
    var sourceURL: URL? {
        get { videoRuntimeValue(\.sourceURL) }
        set { updateVideoRuntime(\.sourceURL, to: newValue) }
    }

    var queuedSourceURLs: [URL] {
        get { videoRuntimeValue(\.queuedSourceURLs) }
        set { updateVideoRuntime(\.queuedSourceURLs, to: newValue) }
    }

    var convertedURL: URL? {
        get { videoRuntimeValue(\.convertedURL) }
        set { updateVideoRuntime(\.convertedURL, to: newValue) }
    }

    var convertedURLs: [URL] {
        get { videoRuntimeValue(\.convertedURLs) }
        set { updateVideoRuntime(\.convertedURLs, to: newValue) }
    }

    var conversionErrorMessage: String? {
        get { videoRuntimeValue(\.conversionErrorMessage) }
        set { updateVideoRuntime(\.conversionErrorMessage, to: newValue) }
    }

    var sourceCompatibilityErrorMessage: String? {
        get { videoRuntimeValue(\.sourceCompatibilityErrorMessage) }
        set { updateVideoRuntime(\.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var sourceCompatibilityWarningMessage: String? {
        get { videoRuntimeValue(\.sourceCompatibilityWarningMessage) }
        set { updateVideoRuntime(\.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingSource: Bool {
        get { videoRuntimeValue(\.isAnalyzingSource) }
        set { updateVideoRuntime(\.isAnalyzingSource, to: newValue) }
    }

    var isConverting: Bool {
        get { videoRuntimeValue(\.isConverting) }
        set { updateVideoRuntime(\.isConverting, to: newValue) }
    }

    var conversionProgress: Double {
        get { videoRuntimeValue(\.conversionProgress) }
        set { updateVideoRuntime(\.conversionProgress, to: newValue) }
    }

    var currentVideoBatchIndex: Int {
        get { videoRuntimeValue(\.currentBatchIndex) }
        set { updateVideoRuntime(\.currentBatchIndex, to: newValue) }
    }

    var totalVideoBatchCount: Int {
        get { videoRuntimeValue(\.totalBatchCount) }
        set { updateVideoRuntime(\.totalBatchCount, to: newValue) }
    }

    var availableOutputFormats: [VideoFormatOption] {
        get { videoRuntimeValue(\.availableOutputFormats) }
        set { updateVideoRuntime(\.availableOutputFormats, to: newValue) }
    }

    var availableVideoEncoders: [VideoEncoderOption] {
        get { videoRuntimeValue(\.availableVideoEncoders) }
        set { updateVideoRuntime(\.availableVideoEncoders, to: newValue) }
    }

    var availableAudioEncoders: [AudioEncoderOption] {
        get { videoRuntimeValue(\.availableAudioEncoders) }
        set { updateVideoRuntime(\.availableAudioEncoders, to: newValue) }
    }

    // Image state
    var imageSourceURL: URL? {
        get { imageRuntimeValue(\.sourceURL) }
        set { updateImageRuntime(\.sourceURL, to: newValue) }
    }

    var queuedImageSourceURLs: [URL] {
        get { imageRuntimeValue(\.queuedSourceURLs) }
        set { updateImageRuntime(\.queuedSourceURLs, to: newValue) }
    }

    var convertedImageURL: URL? {
        get { imageRuntimeValue(\.convertedURL) }
        set { updateImageRuntime(\.convertedURL, to: newValue) }
    }

    var convertedImageURLs: [URL] {
        get { imageRuntimeValue(\.convertedURLs) }
        set { updateImageRuntime(\.convertedURLs, to: newValue) }
    }

    var imageConversionErrorMessage: String? {
        get { imageRuntimeValue(\.conversionErrorMessage) }
        set { updateImageRuntime(\.conversionErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityErrorMessage: String? {
        get { imageRuntimeValue(\.sourceCompatibilityErrorMessage) }
        set { updateImageRuntime(\.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityWarningMessage: String? {
        get { imageRuntimeValue(\.sourceCompatibilityWarningMessage) }
        set { updateImageRuntime(\.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingImageSource: Bool {
        get { imageRuntimeValue(\.isAnalyzingSource) }
        set { updateImageRuntime(\.isAnalyzingSource, to: newValue) }
    }

    var imageSourceFrameCount: Int {
        get { imageRuntimeValue(\.sourceFrameCount) }
        set { updateImageRuntime(\.sourceFrameCount, to: newValue) }
    }

    var imageSourceHasAlpha: Bool {
        get { imageRuntimeValue(\.sourceHasAlpha) }
        set { updateImageRuntime(\.sourceHasAlpha, to: newValue) }
    }

    var isImageConverting: Bool {
        get { imageRuntimeValue(\.isConverting) }
        set { updateImageRuntime(\.isConverting, to: newValue) }
    }

    var imageConversionProgress: Double {
        get { imageRuntimeValue(\.conversionProgress) }
        set { updateImageRuntime(\.conversionProgress, to: newValue) }
    }

    var currentImageBatchIndex: Int {
        get { imageRuntimeValue(\.currentBatchIndex) }
        set { updateImageRuntime(\.currentBatchIndex, to: newValue) }
    }

    var totalImageBatchCount: Int {
        get { imageRuntimeValue(\.totalBatchCount) }
        set { updateImageRuntime(\.totalBatchCount, to: newValue) }
    }

    var availableImageOutputFormats: [ImageFormatOption] {
        get { imageRuntimeValue(\.availableOutputFormats) }
        set { updateImageRuntime(\.availableOutputFormats, to: newValue) }
    }

    // Audio state
    var audioSourceURL: URL? {
        get { audioRuntimeValue(\.sourceURL) }
        set { updateAudioRuntime(\.sourceURL, to: newValue) }
    }

    var queuedAudioSourceURLs: [URL] {
        get { audioRuntimeValue(\.queuedSourceURLs) }
        set { updateAudioRuntime(\.queuedSourceURLs, to: newValue) }
    }

    var convertedAudioURL: URL? {
        get { audioRuntimeValue(\.convertedURL) }
        set { updateAudioRuntime(\.convertedURL, to: newValue) }
    }

    var convertedAudioURLs: [URL] {
        get { audioRuntimeValue(\.convertedURLs) }
        set { updateAudioRuntime(\.convertedURLs, to: newValue) }
    }

    var audioConversionErrorMessage: String? {
        get { audioRuntimeValue(\.conversionErrorMessage) }
        set { updateAudioRuntime(\.conversionErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityErrorMessage: String? {
        get { audioRuntimeValue(\.sourceCompatibilityErrorMessage) }
        set { updateAudioRuntime(\.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityWarningMessage: String? {
        get { audioRuntimeValue(\.sourceCompatibilityWarningMessage) }
        set { updateAudioRuntime(\.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingAudioSource: Bool {
        get { audioRuntimeValue(\.isAnalyzingSource) }
        set { updateAudioRuntime(\.isAnalyzingSource, to: newValue) }
    }

    var isAudioConverting: Bool {
        get { audioRuntimeValue(\.isConverting) }
        set { updateAudioRuntime(\.isConverting, to: newValue) }
    }

    var audioConversionProgress: Double {
        get { audioRuntimeValue(\.conversionProgress) }
        set { updateAudioRuntime(\.conversionProgress, to: newValue) }
    }

    var currentAudioBatchIndex: Int {
        get { audioRuntimeValue(\.currentBatchIndex) }
        set { updateAudioRuntime(\.currentBatchIndex, to: newValue) }
    }

    var totalAudioBatchCount: Int {
        get { audioRuntimeValue(\.totalBatchCount) }
        set { updateAudioRuntime(\.totalBatchCount, to: newValue) }
    }

    var availableAudioOutputFormats: [AudioFormatOption] {
        get { audioRuntimeValue(\.availableOutputFormats) }
        set { updateAudioRuntime(\.availableOutputFormats, to: newValue) }
    }

    var availableAudioOutputEncoders: [AudioEncoderOption] {
        get { audioRuntimeValue(\.availableOutputEncoders) }
        set { updateAudioRuntime(\.availableOutputEncoders, to: newValue) }
    }
}
