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

    // Video state
    var sourceURL: URL? {
        get { runtimeValue(in: \.videoRuntimeState, \.media.sourceURL) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.sourceURL, to: newValue) }
    }

    var queuedSourceURLs: [URL] {
        get { runtimeValue(in: \.videoRuntimeState, \.media.queuedSourceURLs) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.queuedSourceURLs, to: newValue) }
    }

    var convertedURL: URL? {
        get { runtimeValue(in: \.videoRuntimeState, \.media.convertedURL) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.convertedURL, to: newValue) }
    }

    var convertedURLs: [URL] {
        get { runtimeValue(in: \.videoRuntimeState, \.media.convertedURLs) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.convertedURLs, to: newValue) }
    }

    var convertedOutputURLsBySourceID: [String: URL] {
        get { runtimeValue(in: \.videoRuntimeState, \.media.convertedOutputURLsBySourceID) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedSourceIDs: Set<String> {
        get { runtimeValue(in: \.videoRuntimeState, \.media.processedSourceIDs) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.processedSourceIDs, to: newValue) }
    }

    var conversionErrorMessage: String? {
        get { runtimeValue(in: \.videoRuntimeState, \.media.conversionErrorMessage) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.conversionErrorMessage, to: newValue) }
    }

    var sourceCompatibilityErrorMessage: String? {
        get { runtimeValue(in: \.videoRuntimeState, \.media.sourceCompatibilityErrorMessage) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var sourceCompatibilityWarningMessage: String? {
        get { runtimeValue(in: \.videoRuntimeState, \.media.sourceCompatibilityWarningMessage) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingSource: Bool {
        get { runtimeValue(in: \.videoRuntimeState, \.media.isAnalyzingSource) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.isAnalyzingSource, to: newValue) }
    }

    var isConverting: Bool {
        get { runtimeValue(in: \.videoRuntimeState, \.media.isConverting) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.isConverting, to: newValue) }
    }

    var conversionProgress: Double {
        get { runtimeValue(in: \.videoRuntimeState, \.media.conversionProgress) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.conversionProgress, to: newValue) }
    }

    var currentVideoBatchIndex: Int {
        get { runtimeValue(in: \.videoRuntimeState, \.media.currentBatchIndex) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.currentBatchIndex, to: newValue) }
    }

    var totalVideoBatchCount: Int {
        get { runtimeValue(in: \.videoRuntimeState, \.media.totalBatchCount) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.totalBatchCount, to: newValue) }
    }

    var availableOutputFormats: [VideoFormatOption] {
        get { runtimeValue(in: \.videoRuntimeState, \.media.availableOutputFormats) }
        set { setRuntimeValue(in: \.videoRuntimeState, \.media.availableOutputFormats, to: newValue) }
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
        get { runtimeValue(in: \.imageRuntimeState, \.media.sourceURL) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.sourceURL, to: newValue) }
    }

    var queuedImageSourceURLs: [URL] {
        get { runtimeValue(in: \.imageRuntimeState, \.media.queuedSourceURLs) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.queuedSourceURLs, to: newValue) }
    }

    var convertedImageURL: URL? {
        get { runtimeValue(in: \.imageRuntimeState, \.media.convertedURL) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.convertedURL, to: newValue) }
    }

    var convertedImageURLs: [URL] {
        get { runtimeValue(in: \.imageRuntimeState, \.media.convertedURLs) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.convertedURLs, to: newValue) }
    }

    var convertedImageOutputURLsBySourceID: [String: URL] {
        get { runtimeValue(in: \.imageRuntimeState, \.media.convertedOutputURLsBySourceID) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedImageSourceIDs: Set<String> {
        get { runtimeValue(in: \.imageRuntimeState, \.media.processedSourceIDs) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.processedSourceIDs, to: newValue) }
    }

    var imageConversionErrorMessage: String? {
        get { runtimeValue(in: \.imageRuntimeState, \.media.conversionErrorMessage) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.conversionErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityErrorMessage: String? {
        get { runtimeValue(in: \.imageRuntimeState, \.media.sourceCompatibilityErrorMessage) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var imageSourceCompatibilityWarningMessage: String? {
        get { runtimeValue(in: \.imageRuntimeState, \.media.sourceCompatibilityWarningMessage) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingImageSource: Bool {
        get { runtimeValue(in: \.imageRuntimeState, \.media.isAnalyzingSource) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.isAnalyzingSource, to: newValue) }
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
        get { runtimeValue(in: \.imageRuntimeState, \.media.isConverting) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.isConverting, to: newValue) }
    }

    var imageConversionProgress: Double {
        get { runtimeValue(in: \.imageRuntimeState, \.media.conversionProgress) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.conversionProgress, to: newValue) }
    }

    var currentImageBatchIndex: Int {
        get { runtimeValue(in: \.imageRuntimeState, \.media.currentBatchIndex) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.currentBatchIndex, to: newValue) }
    }

    var totalImageBatchCount: Int {
        get { runtimeValue(in: \.imageRuntimeState, \.media.totalBatchCount) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.totalBatchCount, to: newValue) }
    }

    var availableImageOutputFormats: [ImageFormatOption] {
        get { runtimeValue(in: \.imageRuntimeState, \.media.availableOutputFormats) }
        set { setRuntimeValue(in: \.imageRuntimeState, \.media.availableOutputFormats, to: newValue) }
    }

    // Audio state
    var audioSourceURL: URL? {
        get { runtimeValue(in: \.audioRuntimeState, \.media.sourceURL) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.sourceURL, to: newValue) }
    }

    var queuedAudioSourceURLs: [URL] {
        get { runtimeValue(in: \.audioRuntimeState, \.media.queuedSourceURLs) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.queuedSourceURLs, to: newValue) }
    }

    var convertedAudioURL: URL? {
        get { runtimeValue(in: \.audioRuntimeState, \.media.convertedURL) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.convertedURL, to: newValue) }
    }

    var convertedAudioURLs: [URL] {
        get { runtimeValue(in: \.audioRuntimeState, \.media.convertedURLs) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.convertedURLs, to: newValue) }
    }

    var convertedAudioOutputURLsBySourceID: [String: URL] {
        get { runtimeValue(in: \.audioRuntimeState, \.media.convertedOutputURLsBySourceID) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.convertedOutputURLsBySourceID, to: newValue) }
    }

    var processedAudioSourceIDs: Set<String> {
        get { runtimeValue(in: \.audioRuntimeState, \.media.processedSourceIDs) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.processedSourceIDs, to: newValue) }
    }

    var audioConversionErrorMessage: String? {
        get { runtimeValue(in: \.audioRuntimeState, \.media.conversionErrorMessage) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.conversionErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityErrorMessage: String? {
        get { runtimeValue(in: \.audioRuntimeState, \.media.sourceCompatibilityErrorMessage) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.sourceCompatibilityErrorMessage, to: newValue) }
    }

    var audioSourceCompatibilityWarningMessage: String? {
        get { runtimeValue(in: \.audioRuntimeState, \.media.sourceCompatibilityWarningMessage) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.sourceCompatibilityWarningMessage, to: newValue) }
    }

    var isAnalyzingAudioSource: Bool {
        get { runtimeValue(in: \.audioRuntimeState, \.media.isAnalyzingSource) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.isAnalyzingSource, to: newValue) }
    }

    var isAudioConverting: Bool {
        get { runtimeValue(in: \.audioRuntimeState, \.media.isConverting) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.isConverting, to: newValue) }
    }

    var audioConversionProgress: Double {
        get { runtimeValue(in: \.audioRuntimeState, \.media.conversionProgress) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.conversionProgress, to: newValue) }
    }

    var currentAudioBatchIndex: Int {
        get { runtimeValue(in: \.audioRuntimeState, \.media.currentBatchIndex) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.currentBatchIndex, to: newValue) }
    }

    var totalAudioBatchCount: Int {
        get { runtimeValue(in: \.audioRuntimeState, \.media.totalBatchCount) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.totalBatchCount, to: newValue) }
    }

    var availableAudioOutputFormats: [AudioFormatOption] {
        get { runtimeValue(in: \.audioRuntimeState, \.media.availableOutputFormats) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.media.availableOutputFormats, to: newValue) }
    }

    var availableAudioOutputEncoders: [AudioEncoderOption] {
        get { runtimeValue(in: \.audioRuntimeState, \.availableOutputEncoders) }
        set { setRuntimeValue(in: \.audioRuntimeState, \.availableOutputEncoders, to: newValue) }
    }
}
