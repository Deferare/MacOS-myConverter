import Foundation

extension ContentViewModel.MediaKind {
    func launchConversionTask(
        in viewModel: ContentViewModel,
        operation: @escaping @MainActor () async -> Void
    ) {
        let descriptor = mediaStateDescriptor
        guard viewModel[keyPath: descriptor.conversionTask] == nil else { return }
        guard !viewModel[keyPath: descriptor.isConverting] else { return }

        viewModel[keyPath: descriptor.conversionTask] = Task { @MainActor [weak viewModel] in
            defer { viewModel.map { self.clearConversionTask(in: $0) } }
            await operation()
        }
    }

    func cancelConversionTask(in viewModel: ContentViewModel) {
        #if os(iOS)
        EmbeddedFFmpegBridge.cancelCurrentCommand()
        #endif
        let descriptor = mediaStateDescriptor
        guard let task = viewModel[keyPath: descriptor.conversionTask] else { return }
        task.cancel()
    }

    func clearConversionTask(in viewModel: ContentViewModel) {
        viewModel[keyPath: mediaStateDescriptor.conversionTask] = nil
    }

    func startConversion(in viewModel: ContentViewModel) {
        launchConversionTask(in: viewModel) { [weak viewModel] in
            if let viewModel {
                await self.performConversion(in: viewModel)
            }
        }
    }

    func cancelConversion(in viewModel: ContentViewModel) {
        cancelConversionTask(in: viewModel)
    }
}
