import Foundation

extension ContentViewModel {
    func setProgress(_ rawProgress: Double, at keyPath: ReferenceWritableKeyPath<ContentViewModel, Double>) {
        let clamped = clampedProgress(rawProgress)
        let current = self[keyPath: keyPath]
        guard current != clamped else { return }
        self[keyPath: keyPath] = clamped
        PerformanceSignpost.event("ProgressPublish")
    }

    func normalizedBatchProgress(
        itemProgress: Double,
        index: Int,
        totalCount: Int
    ) -> Double {
        let base = Double(index)
        let total = Double(max(totalCount, 1))
        return (base + itemProgress) / total
    }
}

extension ContentViewModel.MediaKind {
    nonisolated
    func batchProgressHandler(
        in viewModel: ContentViewModel,
        index: Int,
        totalCount: Int
    ) -> @Sendable (Double) async -> Void {
        { [weak viewModel] progress in
            guard let viewModel else { return }
            await self.updateBatchProgress(
                in: viewModel,
                itemProgress: progress,
                index: index,
                totalCount: totalCount
            )
        }
    }

    func setProgress(_ rawProgress: Double, in viewModel: ContentViewModel) {
        viewModel.setProgress(rawProgress, at: mediaStateDescriptor.progress)
    }

    func updateBatchProgress(
        in viewModel: ContentViewModel,
        itemProgress: Double,
        index: Int,
        totalCount: Int
    ) {
        setProgress(
            viewModel.normalizedBatchProgress(
                itemProgress: itemProgress,
                index: index,
                totalCount: totalCount
            ),
            in: viewModel
        )
    }
}
