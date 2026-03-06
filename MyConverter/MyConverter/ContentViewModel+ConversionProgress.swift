import Foundation

extension ContentViewModel {
    func setProgress(_ rawProgress: Double, at keyPath: ReferenceWritableKeyPath<ContentViewModel, Double>) {
        let clamped = clampedProgress(rawProgress)
        let current = self[keyPath: keyPath]
        guard current != clamped else { return }

        let shouldForceUpdate = clamped == 0 || clamped == 1
        guard shouldForceUpdate || abs(current - clamped) >= 0.002 else { return }
        self[keyPath: keyPath] = clamped
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

    func updateConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.conversionProgress)
    }

    func updateImageConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.imageConversionProgress)
    }

    func updateAudioConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.audioConversionProgress)
    }
}
