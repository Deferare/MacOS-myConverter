import Foundation

extension ContentViewModel {
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

    func prepareConversionStartState() {
        prepareBatchStartState(
            runningKeyPath: \.isConverting,
            primaryOutputKeyPath: \.convertedURL,
            outputsKeyPath: \.convertedURLs,
            errorMessageKeyPath: \.conversionErrorMessage,
            progressKeyPath: \.conversionProgress
        )
    }

    func prepareImageConversionStartState() {
        prepareBatchStartState(
            runningKeyPath: \.isImageConverting,
            primaryOutputKeyPath: \.convertedImageURL,
            outputsKeyPath: \.convertedImageURLs,
            errorMessageKeyPath: \.imageConversionErrorMessage,
            progressKeyPath: \.imageConversionProgress
        )
    }

    func prepareAudioConversionStartState() {
        prepareBatchStartState(
            runningKeyPath: \.isAudioConverting,
            primaryOutputKeyPath: \.convertedAudioURL,
            outputsKeyPath: \.convertedAudioURLs,
            errorMessageKeyPath: \.audioConversionErrorMessage,
            progressKeyPath: \.audioConversionProgress
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

    func applyConversionError(_ error: Error) {
        if case ConversionError.exportCancelled = error {
            conversionErrorMessage = nil
            return
        }

        conversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

        if let conversionError = error as? ConversionError {
            print("Conversion failed: \(conversionError.debugInfo)")
        } else {
            print("Conversion failed: \(error.localizedDescription)")
        }
    }

    func applyImageConversionError(_ error: Error) {
        imageConversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        print("Image conversion failed: \(imageConversionErrorMessage ?? error.localizedDescription)")
    }

    func applyAudioConversionError(_ error: Error) {
        if case ConversionError.exportCancelled = error {
            audioConversionErrorMessage = nil
            return
        }

        audioConversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        print("Audio conversion failed: \(audioConversionErrorMessage ?? error.localizedDescription)")
    }

    func removeProcessedVideoSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedVideoSourceURLs,
            assignSelection: assignVideoSelection(_:),
            onSelectionEmptied: {
                resetVideoCompatibilityMessages()
                isAnalyzingSource = false
                availableOutputFormats = VideoConversionEngine.defaultOutputFormats()
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    func removeProcessedImageSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedImageSourceURLs,
            assignSelection: assignImageSelection(_:),
            onSelectionEmptied: {
                resetImageCompatibilityState(resetMetadata: true)
                isAnalyzingImageSource = false
                availableImageOutputFormats = ImageConversionEngine.defaultOutputFormats()
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    func removeProcessedAudioSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedAudioSourceURLs,
            assignSelection: assignAudioSelection(_:),
            onSelectionEmptied: {
                resetAudioCompatibilityMessages()
                isAnalyzingAudioSource = false
                availableAudioOutputFormats = VideoConversionEngine.defaultAudioOutputFormats()
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }
}
