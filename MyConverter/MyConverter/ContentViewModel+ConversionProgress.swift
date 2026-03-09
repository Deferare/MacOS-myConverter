import Foundation

extension ContentViewModel {
    func batchProgressHandler(
        for kind: MediaKind,
        index: Int,
        totalCount: Int
    ) -> @Sendable (Double) async -> Void {
        { [weak self] progress in
            guard let self else { return }
            await self.updateBatchProgress(
                for: kind,
                itemProgress: progress,
                index: index,
                totalCount: totalCount
            )
        }
    }

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

    func setProgress(_ rawProgress: Double, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)
        setProgress(rawProgress, at: descriptor.progress)
    }

    func updateBatchProgress(
        for kind: MediaKind,
        itemProgress: Double,
        index: Int,
        totalCount: Int
    ) {
        setProgress(
            normalizedBatchProgress(
                itemProgress: itemProgress,
                index: index,
                totalCount: totalCount
            ),
            for: kind
        )
    }
}
