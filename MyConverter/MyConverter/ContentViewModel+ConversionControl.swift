import Foundation

extension ContentViewModel.MediaKind {
    func launchConversionTask(
        in viewModel: ContentViewModel,
        operation: @escaping @MainActor () async -> Void
    ) {
        guard conversionTask(in: viewModel) == nil else { return }
        guard !isConverting(in: viewModel) else { return }

        setConversionTask(Task { @MainActor [weak viewModel] in
            defer { viewModel.map { self.clearConversionTask(in: $0) } }
            await operation()
        }, in: viewModel)
    }

    func cancelConversionTask(in viewModel: ContentViewModel) {
        #if os(iOS)
        EmbeddedFFmpegBridge.cancelCurrentCommand()
        #endif
        guard let task = conversionTask(in: viewModel) else { return }
        task.cancel()
    }

    func clearConversionTask(in viewModel: ContentViewModel) {
        setConversionTask(nil, in: viewModel)
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
