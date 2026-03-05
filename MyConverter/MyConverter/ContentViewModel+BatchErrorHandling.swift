import Foundation

extension ContentViewModel {
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
}
