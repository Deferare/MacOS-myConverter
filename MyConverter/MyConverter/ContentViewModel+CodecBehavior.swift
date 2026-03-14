import Foundation

extension ContentViewModel.MediaKind {
    private struct CodecBehavior {
        let refreshCodecOptions: (ContentViewModel) -> Void
        let applyPlaceholderCodecOptions: (ContentViewModel) -> Void
        let normalizeOptionDependencies: (ContentViewModel) -> Void
    }

    private static let codecBehaviorByKind: [Self: CodecBehavior] = [
        .video: CodecBehavior(
            refreshCodecOptions: { $0.refreshVideoCodecOptions() },
            applyPlaceholderCodecOptions: { $0.applyPlaceholderVideoCodecOptions() },
            normalizeOptionDependencies: { $0.normalizeVideoOptionDependencies() }
        ),
        .image: CodecBehavior(
            refreshCodecOptions: { _ in },
            applyPlaceholderCodecOptions: { _ in },
            normalizeOptionDependencies: { _ in }
        ),
        .audio: CodecBehavior(
            refreshCodecOptions: { $0.refreshAudioCodecOptions() },
            applyPlaceholderCodecOptions: { $0.applyPlaceholderAudioCodecOptions() },
            normalizeOptionDependencies: { $0.normalizeAudioOptionDependencies() }
        )
    ]

    private var codecBehavior: CodecBehavior {
        Self.codecBehaviorByKind[self] ?? Self.codecBehaviorByKind[.video]!
    }

    func refreshCodecOptions(in viewModel: ContentViewModel) {
        codecBehavior.refreshCodecOptions(viewModel)
    }

    func applyPlaceholderCodecOptions(to viewModel: ContentViewModel) {
        codecBehavior.applyPlaceholderCodecOptions(viewModel)
    }

    func normalizeOptionDependencies(in viewModel: ContentViewModel) {
        codecBehavior.normalizeOptionDependencies(viewModel)
    }
}
