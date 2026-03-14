import Foundation

extension ContentViewModel {
    func launchConversionTask(
        for kind: MediaKind,
        operation: @escaping @MainActor () async -> Void
    ) {
        let descriptor = kind.mediaStateDescriptor
        guard self[keyPath: descriptor.conversionTask] == nil else { return }
        guard !self[keyPath: descriptor.isConverting] else { return }

        self[keyPath: descriptor.conversionTask] = Task { @MainActor [weak self] in
            defer { self?.clearConversionTask(for: kind) }
            await operation()
        }
    }

    func cancelConversionTask(for kind: MediaKind) {
        #if os(iOS)
        EmbeddedFFmpegBridge.cancelCurrentCommand()
        #endif
        let descriptor = kind.mediaStateDescriptor
        guard let task = self[keyPath: descriptor.conversionTask] else { return }
        task.cancel()
    }

    func clearConversionTask(for kind: MediaKind) {
        let descriptor = kind.mediaStateDescriptor
        self[keyPath: descriptor.conversionTask] = nil
    }
}

extension ContentViewModel.MediaKind {
    func startConversion(in viewModel: ContentViewModel) {
        viewModel.launchConversionTask(for: self) { [weak viewModel] in
            if let viewModel {
                await self.performConversion(in: viewModel)
            }
        }
    }

    func cancelConversion(in viewModel: ContentViewModel) {
        viewModel.cancelConversionTask(for: self)
    }
}
