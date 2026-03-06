import Foundation

extension ContentViewModel {
    // Video state
    var sourceURL: URL? {
        get { stateValue(in: \.videoRuntimeState, at: \.sourceURL) }
        set { updateState(\.videoRuntimeState, value: \.sourceURL, to: newValue) }
    }

    var queuedSourceURLs: [URL] {
        get { stateValue(in: \.videoRuntimeState, at: \.queuedSourceURLs) }
        set { updateState(\.videoRuntimeState, value: \.queuedSourceURLs, to: newValue) }
    }

    var convertedURL: URL? {
        get { stateValue(in: \.videoRuntimeState, at: \.convertedURL) }
        set { updateState(\.videoRuntimeState, value: \.convertedURL, to: newValue) }
    }

    var convertedURLs: [URL] {
        get { stateValue(in: \.videoRuntimeState, at: \.convertedURLs) }
        set { updateState(\.videoRuntimeState, value: \.convertedURLs, to: newValue) }
    }

    var conversionErrorMessage: String? {
        get { stateValue(in: \.videoRuntimeState, at: \.conversionErrorMessage) }
        set { updateState(\.videoRuntimeState, value: \.conversionErrorMessage, to: newValue) }
    }

    var sourceCompatibilityErrorMessage: String? {
        get { stateValue(in: \.videoRuntimeState, at: \.sourceCompatibilityErrorMessage) }
        set { updateState(\.videoRuntimeState, value: \.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var sourceCompatibilityWarningMessage: String? {
        get { stateValue(in: \.videoRuntimeState, at: \.sourceCompatibilityWarningMessage) }
        set { updateState(\.videoRuntimeState, value: \.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingSource: Bool {
        get { stateValue(in: \.videoRuntimeState, at: \.isAnalyzingSource) }
        set { updateState(\.videoRuntimeState, value: \.isAnalyzingSource, to: newValue) }
    }

    var isConverting: Bool {
        get { stateValue(in: \.videoRuntimeState, at: \.isConverting) }
        set { updateState(\.videoRuntimeState, value: \.isConverting, to: newValue) }
    }

    var conversionProgress: Double {
        get { stateValue(in: \.videoRuntimeState, at: \.conversionProgress) }
        set { updateState(\.videoRuntimeState, value: \.conversionProgress, to: newValue) }
    }

    var currentVideoBatchIndex: Int {
        get { stateValue(in: \.videoRuntimeState, at: \.currentBatchIndex) }
        set { updateState(\.videoRuntimeState, value: \.currentBatchIndex, to: newValue) }
    }

    var totalVideoBatchCount: Int {
        get { stateValue(in: \.videoRuntimeState, at: \.totalBatchCount) }
        set { updateState(\.videoRuntimeState, value: \.totalBatchCount, to: newValue) }
    }

    var availableOutputFormats: [VideoFormatOption] {
        get { stateValue(in: \.videoRuntimeState, at: \.availableOutputFormats) }
        set { updateState(\.videoRuntimeState, value: \.availableOutputFormats, to: newValue) }
    }

    var availableVideoEncoders: [VideoEncoderOption] {
        get { stateValue(in: \.videoRuntimeState, at: \.availableVideoEncoders) }
        set { updateState(\.videoRuntimeState, value: \.availableVideoEncoders, to: newValue) }
    }

    var availableAudioEncoders: [AudioEncoderOption] {
        get { stateValue(in: \.videoRuntimeState, at: \.availableAudioEncoders) }
        set { updateState(\.videoRuntimeState, value: \.availableAudioEncoders, to: newValue) }
    }

    // Image state
    var imageSourceURL: URL? {
        get { stateValue(in: \.imageRuntimeState, at: \.sourceURL) }
        set { updateState(\.imageRuntimeState, value: \.sourceURL, to: newValue) }
    }

    var queuedImageSourceURLs: [URL] {
        get { stateValue(in: \.imageRuntimeState, at: \.queuedSourceURLs) }
        set { updateState(\.imageRuntimeState, value: \.queuedSourceURLs, to: newValue) }
    }

    var convertedImageURL: URL? {
        get { stateValue(in: \.imageRuntimeState, at: \.convertedURL) }
        set { updateState(\.imageRuntimeState, value: \.convertedURL, to: newValue) }
    }

    var convertedImageURLs: [URL] {
        get { stateValue(in: \.imageRuntimeState, at: \.convertedURLs) }
        set { updateState(\.imageRuntimeState, value: \.convertedURLs, to: newValue) }
    }

    var imageConversionErrorMessage: String? {
        get { stateValue(in: \.imageRuntimeState, at: \.conversionErrorMessage) }
        set { updateState(\.imageRuntimeState, value: \.conversionErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityErrorMessage: String? {
        get { stateValue(in: \.imageRuntimeState, at: \.sourceCompatibilityErrorMessage) }
        set { updateState(\.imageRuntimeState, value: \.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityWarningMessage: String? {
        get { stateValue(in: \.imageRuntimeState, at: \.sourceCompatibilityWarningMessage) }
        set { updateState(\.imageRuntimeState, value: \.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingImageSource: Bool {
        get { stateValue(in: \.imageRuntimeState, at: \.isAnalyzingSource) }
        set { updateState(\.imageRuntimeState, value: \.isAnalyzingSource, to: newValue) }
    }

    var imageSourceFrameCount: Int {
        get { stateValue(in: \.imageRuntimeState, at: \.sourceFrameCount) }
        set { updateState(\.imageRuntimeState, value: \.sourceFrameCount, to: newValue) }
    }

    var imageSourceHasAlpha: Bool {
        get { stateValue(in: \.imageRuntimeState, at: \.sourceHasAlpha) }
        set { updateState(\.imageRuntimeState, value: \.sourceHasAlpha, to: newValue) }
    }

    var isImageConverting: Bool {
        get { stateValue(in: \.imageRuntimeState, at: \.isConverting) }
        set { updateState(\.imageRuntimeState, value: \.isConverting, to: newValue) }
    }

    var imageConversionProgress: Double {
        get { stateValue(in: \.imageRuntimeState, at: \.conversionProgress) }
        set { updateState(\.imageRuntimeState, value: \.conversionProgress, to: newValue) }
    }

    var currentImageBatchIndex: Int {
        get { stateValue(in: \.imageRuntimeState, at: \.currentBatchIndex) }
        set { updateState(\.imageRuntimeState, value: \.currentBatchIndex, to: newValue) }
    }

    var totalImageBatchCount: Int {
        get { stateValue(in: \.imageRuntimeState, at: \.totalBatchCount) }
        set { updateState(\.imageRuntimeState, value: \.totalBatchCount, to: newValue) }
    }

    var availableImageOutputFormats: [ImageFormatOption] {
        get { stateValue(in: \.imageRuntimeState, at: \.availableOutputFormats) }
        set { updateState(\.imageRuntimeState, value: \.availableOutputFormats, to: newValue) }
    }

    // Audio state
    var audioSourceURL: URL? {
        get { stateValue(in: \.audioRuntimeState, at: \.sourceURL) }
        set { updateState(\.audioRuntimeState, value: \.sourceURL, to: newValue) }
    }

    var queuedAudioSourceURLs: [URL] {
        get { stateValue(in: \.audioRuntimeState, at: \.queuedSourceURLs) }
        set { updateState(\.audioRuntimeState, value: \.queuedSourceURLs, to: newValue) }
    }

    var convertedAudioURL: URL? {
        get { stateValue(in: \.audioRuntimeState, at: \.convertedURL) }
        set { updateState(\.audioRuntimeState, value: \.convertedURL, to: newValue) }
    }

    var convertedAudioURLs: [URL] {
        get { stateValue(in: \.audioRuntimeState, at: \.convertedURLs) }
        set { updateState(\.audioRuntimeState, value: \.convertedURLs, to: newValue) }
    }

    var audioConversionErrorMessage: String? {
        get { stateValue(in: \.audioRuntimeState, at: \.conversionErrorMessage) }
        set { updateState(\.audioRuntimeState, value: \.conversionErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityErrorMessage: String? {
        get { stateValue(in: \.audioRuntimeState, at: \.sourceCompatibilityErrorMessage) }
        set { updateState(\.audioRuntimeState, value: \.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityWarningMessage: String? {
        get { stateValue(in: \.audioRuntimeState, at: \.sourceCompatibilityWarningMessage) }
        set { updateState(\.audioRuntimeState, value: \.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingAudioSource: Bool {
        get { stateValue(in: \.audioRuntimeState, at: \.isAnalyzingSource) }
        set { updateState(\.audioRuntimeState, value: \.isAnalyzingSource, to: newValue) }
    }

    var isAudioConverting: Bool {
        get { stateValue(in: \.audioRuntimeState, at: \.isConverting) }
        set { updateState(\.audioRuntimeState, value: \.isConverting, to: newValue) }
    }

    var audioConversionProgress: Double {
        get { stateValue(in: \.audioRuntimeState, at: \.conversionProgress) }
        set { updateState(\.audioRuntimeState, value: \.conversionProgress, to: newValue) }
    }

    var currentAudioBatchIndex: Int {
        get { stateValue(in: \.audioRuntimeState, at: \.currentBatchIndex) }
        set { updateState(\.audioRuntimeState, value: \.currentBatchIndex, to: newValue) }
    }

    var totalAudioBatchCount: Int {
        get { stateValue(in: \.audioRuntimeState, at: \.totalBatchCount) }
        set { updateState(\.audioRuntimeState, value: \.totalBatchCount, to: newValue) }
    }

    var availableAudioOutputFormats: [AudioFormatOption] {
        get { stateValue(in: \.audioRuntimeState, at: \.availableOutputFormats) }
        set { updateState(\.audioRuntimeState, value: \.availableOutputFormats, to: newValue) }
    }

    var availableAudioOutputEncoders: [AudioEncoderOption] {
        get { stateValue(in: \.audioRuntimeState, at: \.availableOutputEncoders) }
        set { updateState(\.audioRuntimeState, value: \.availableOutputEncoders, to: newValue) }
    }
}
