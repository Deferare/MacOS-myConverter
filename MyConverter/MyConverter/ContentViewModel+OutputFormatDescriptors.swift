import Foundation

extension ContentViewModel {
    struct OutputFormatDescriptor<Format> {
        let sourceURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let availableFormats: ReferenceWritableKeyPath<ContentViewModel, [Format]>
        let selectedFormat: ReferenceWritableKeyPath<ContentViewModel, Format>
        let placeholderFormats: () -> [Format]
        let formatNormalizedID: (Format) -> String
        let formatDisplayName: (Format) -> String
        let formatFileExtension: (Format) -> String
        let preferredSelection: ([Format]) -> Format?
    }

    static let videoOutputFormatDescriptor = OutputFormatDescriptor(
        sourceURL: \.videoRuntimeState.media.sourceURL,
        availableFormats: \.videoRuntimeState.media.availableOutputFormats,
        selectedFormat: \.videoOptionsState.selectedOutputFormat,
        placeholderFormats: { ContentViewModelSupport.placeholderVideoFormats() },
        formatNormalizedID: { $0.normalizedID },
        formatDisplayName: { $0.displayName },
        formatFileExtension: { $0.fileExtension },
        preferredSelection: VideoFormatOption.defaultSelection(from:)
    )

    static let imageOutputFormatDescriptor = OutputFormatDescriptor(
        sourceURL: \.imageRuntimeState.media.sourceURL,
        availableFormats: \.imageRuntimeState.media.availableOutputFormats,
        selectedFormat: \.imageOptionsState.selectedOutputFormat,
        placeholderFormats: { ContentViewModelSupport.placeholderImageFormats() },
        formatNormalizedID: { $0.normalizedID },
        formatDisplayName: { $0.displayName },
        formatFileExtension: { $0.fileExtension },
        preferredSelection: { $0.first }
    )

    static let audioOutputFormatDescriptor = OutputFormatDescriptor(
        sourceURL: \.audioRuntimeState.media.sourceURL,
        availableFormats: \.audioRuntimeState.media.availableOutputFormats,
        selectedFormat: \.audioOptionsState.selectedOutputFormat,
        placeholderFormats: { ContentViewModelSupport.placeholderAudioFormats() },
        formatNormalizedID: { $0.normalizedID },
        formatDisplayName: { $0.displayName },
        formatFileExtension: { $0.fileExtension },
        preferredSelection: AudioFormatOption.defaultSelection(from:)
    )
}
