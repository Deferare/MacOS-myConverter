import Foundation

extension ContentViewModel {
    func prepareConversionStartState(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        prepareBatchStartState(
            runningKeyPath: descriptor.isConverting,
            primaryOutputKeyPath: descriptor.convertedURL,
            outputsKeyPath: descriptor.convertedURLs,
            errorMessageKeyPath: descriptor.conversionErrorMessage,
            progressKeyPath: descriptor.progress
        )
    }

    func prepareBatchStartState(
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        primaryOutputKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        outputsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>
    ) {
        self[keyPath: runningKeyPath] = true
        self[keyPath: primaryOutputKeyPath] = nil
        self[keyPath: outputsKeyPath] = []
        self[keyPath: errorMessageKeyPath] = nil
        self[keyPath: progressKeyPath] = 0
    }

    func appendConvertedOutput(_ outputURL: URL, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        appendConvertedOutput(
            outputURL,
            primaryOutputKeyPath: descriptor.convertedURL,
            outputsKeyPath: descriptor.convertedURLs
        )
    }

    func appendConvertedOutput(
        _ outputURL: URL,
        primaryOutputKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        outputsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>
    ) {
        self[keyPath: primaryOutputKeyPath] = outputURL
        var outputs = self[keyPath: outputsKeyPath]
        outputs.append(outputURL)
        self[keyPath: outputsKeyPath] = outputs
    }
}
