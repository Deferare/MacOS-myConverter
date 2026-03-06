import Foundation

extension ContentViewModel {
    func clearSelectedSource() {
        clearSelectedSource(for: .video)
    }

    func clearSelectedVideoSource() {
        clearSelectedSource(for: .video)
    }

    func clearSelectedImageSource() {
        clearSelectedSource(for: .image)
    }

    func clearSelectedAudioSource() {
        clearSelectedSource(for: .audio)
    }
}
