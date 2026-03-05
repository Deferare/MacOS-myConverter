import Foundation

extension ContentViewModel {
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
}
