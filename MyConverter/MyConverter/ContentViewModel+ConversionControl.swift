import Foundation

extension ContentViewModel {
    func startConversion() {
        launchConversionTask(for: .video) { [weak self] in
            await self?.convert()
        }
    }

    func cancelConversion() {
        cancelConversionTask(for: .video)
    }

    func startImageConversion() {
        launchConversionTask(for: .image) { [weak self] in
            await self?.convertImage()
        }
    }

    func cancelImageConversion() {
        cancelConversionTask(for: .image)
    }

    func startAudioConversion() {
        launchConversionTask(for: .audio) { [weak self] in
            await self?.convertAudio()
        }
    }

    func cancelAudioConversion() {
        cancelConversionTask(for: .audio)
    }

    func launchConversionTask(
        for kind: MediaKind,
        operation: @escaping @MainActor () async -> Void
    ) {
        let descriptor = mediaStateDescriptor(for: kind)
        guard !self[keyPath: descriptor.isConverting] else { return }

        self[keyPath: descriptor.conversionTask] = Task {
            await operation()
        }
    }

    func cancelConversionTask(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        guard self[keyPath: descriptor.isConverting] else { return }
        self[keyPath: descriptor.conversionTask]?.cancel()
    }
}
