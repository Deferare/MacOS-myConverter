import Foundation

extension ContentViewModel {
    func prepareConversionStartState() {
        prepareConversionStartState(for: .video)
    }

    func prepareImageConversionStartState() {
        prepareConversionStartState(for: .image)
    }

    func prepareAudioConversionStartState() {
        prepareConversionStartState(for: .audio)
    }
}
