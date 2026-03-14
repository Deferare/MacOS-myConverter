import Foundation

extension ContentViewModel {
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
            await performVideoConversion()
        case .image:
            await performImageConversion()
        case .audio:
            await performAudioConversion()
        }
    }

    func launchConversionTask(
        for kind: MediaKind,
        operation: @escaping @MainActor () async -> Void
    ) {
        let descriptor = mediaStateDescriptor(for: kind)
        guard currentConversionTask(for: kind) == nil else { return }
        guard !self[keyPath: descriptor.isConverting] else { return }

        setConversionTask(Task { @MainActor [weak self] in
            defer { self?.clearConversionTask(for: kind) }
            await operation()
        }, for: kind)
    }

    func cancelConversionTask(for kind: MediaKind) {
        #if os(iOS)
        EmbeddedFFmpegBridge.cancelCurrentCommand()
        #endif
        guard let task = currentConversionTask(for: kind) else { return }
        task.cancel()
    }

    func clearConversionTask(for kind: MediaKind) {
        setConversionTask(nil, for: kind)
    }
}
