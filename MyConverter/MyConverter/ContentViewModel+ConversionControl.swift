import Foundation

extension ContentViewModel {
    func startConversion() {
        startConversion(for: .video)
    }

    func cancelConversion() {
        cancelConversion(for: .video)
    }

    func startImageConversion() {
        startConversion(for: .image)
    }

    func cancelImageConversion() {
        cancelConversion(for: .image)
    }

    func startAudioConversion() {
        startConversion(for: .audio)
    }

    func cancelAudioConversion() {
        cancelConversion(for: .audio)
    }

    func startConversion(for kind: MediaKind) {
        launchConversionTask(for: kind) { [weak self] in
            await self?.runConversion(for: kind)
        }
    }

    func cancelConversion(for kind: MediaKind) {
        cancelConversionTask(for: kind)
    }

    func runConversion(for kind: MediaKind) async {
        switch kind {
        case .video:
            await convertVideo()
        case .image:
            await convertImage()
        case .audio:
            await convertAudio()
        }
    }

    func launchConversionTask(
        for kind: MediaKind,
        operation: @escaping @MainActor () async -> Void
    ) {
        let descriptor = mediaStateDescriptor(for: kind)
        guard self[keyPath: descriptor.conversionTask] == nil else { return }
        guard !self[keyPath: descriptor.isConverting] else { return }

        self[keyPath: descriptor.conversionTask] = Task { @MainActor [weak self] in
            defer { self?.clearConversionTask(for: kind) }
            await operation()
        }
    }

    func cancelConversionTask(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        guard let task = self[keyPath: descriptor.conversionTask] else { return }
        task.cancel()
    }

    func clearConversionTask(for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        self[keyPath: descriptor.conversionTask] = nil
    }
}
