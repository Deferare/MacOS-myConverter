import Foundation

extension ContentViewModel {
    func imageSourceAnalysisDescriptor() -> SourceAnalysisDescriptor<ImageSourceCapabilities, ImageFormatOption> {
        makeCapabilitySummaryDescriptor(
            kind: .image,
            availableFormatsKeyPath: \.availableImageOutputFormats,
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            formatNormalizedID: { $0.normalizedID },
            deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output format is available for the selected files.",
            buildSelectionHandlers: makeImageSourceSelectionHandlers()
        )
    }
}
