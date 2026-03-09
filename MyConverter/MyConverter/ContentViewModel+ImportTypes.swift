import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    struct ConversionMetadata {
        let outputLabel: String
        let missingSourceLog: String
        let destinationErrorCode: Int
        let skippedSummaryPrefix: String
        let treatExportCancellationAsCancelled: Bool
        let errorLogPrefix: String
        let includeDebugInfo: Bool
    }

    struct MediaDescriptor {
        let sidebarSystemImage: String
        let usesFilledInputSystemImage: Bool
        let selectedOutputFormatLabel: (ContentViewModel) -> String
        let saveSettingsFailureContext: String
        let loadSettingsFailureContext: String
        let conversionMetadata: ConversionMetadata
        let acceptsInput: (URL) -> Bool
        let preferredImportTypes: (UTType?) -> [UTType]
    }
}

extension ContentViewModel.MediaKind {
    var descriptor: ContentViewModel.MediaDescriptor {
        switch self {
        case .video:
            return ContentViewModel.MediaDescriptor(
                sidebarSystemImage: "film",
                usesFilledInputSystemImage: true,
                selectedOutputFormatLabel: { viewModel in
                    viewModel.selectedOutputFormatLabel(using: viewModel.videoOutputFormatDescriptor())
                },
                saveSettingsFailureContext: "Failed to persist video settings",
                loadSettingsFailureContext: "Failed to load persisted video settings",
                conversionMetadata: ContentViewModel.ConversionMetadata(
                    outputLabel: "Video",
                    missingSourceLog: "No file to convert.",
                    destinationErrorCode: -1001,
                    skippedSummaryPrefix: "Some video files were skipped:",
                    treatExportCancellationAsCancelled: true,
                    errorLogPrefix: "Conversion failed",
                    includeDebugInfo: true
                ),
                acceptsInput: ContentViewModelSupport.isVideoInputURL(_:),
                preferredImportTypes: { [.movie, .video, $0].compactMap { $0 } }
            )
        case .image:
            return ContentViewModel.MediaDescriptor(
                sidebarSystemImage: "photo",
                usesFilledInputSystemImage: true,
                selectedOutputFormatLabel: { viewModel in
                    viewModel.selectedOutputFormatLabel(using: viewModel.imageOutputFormatDescriptor())
                },
                saveSettingsFailureContext: "Failed to persist image settings",
                loadSettingsFailureContext: "Failed to load persisted image settings",
                conversionMetadata: ContentViewModel.ConversionMetadata(
                    outputLabel: "Image",
                    missingSourceLog: "No image file to convert.",
                    destinationErrorCode: -1002,
                    skippedSummaryPrefix: "Some image files were skipped:",
                    treatExportCancellationAsCancelled: false,
                    errorLogPrefix: "Image conversion failed",
                    includeDebugInfo: false
                ),
                acceptsInput: ContentViewModelSupport.isImageInputURL(_:),
                preferredImportTypes: { _ in [.image] }
            )
        case .audio:
            return ContentViewModel.MediaDescriptor(
                sidebarSystemImage: "waveform",
                usesFilledInputSystemImage: false,
                selectedOutputFormatLabel: { viewModel in
                    viewModel.selectedOutputFormatLabel(using: viewModel.audioOutputFormatDescriptor())
                },
                saveSettingsFailureContext: "Failed to persist audio settings",
                loadSettingsFailureContext: "Failed to load persisted audio settings",
                conversionMetadata: ContentViewModel.ConversionMetadata(
                    outputLabel: "Audio",
                    missingSourceLog: "No audio file to convert.",
                    destinationErrorCode: -1003,
                    skippedSummaryPrefix: "Some audio files were skipped:",
                    treatExportCancellationAsCancelled: true,
                    errorLogPrefix: "Audio conversion failed",
                    includeDebugInfo: false
                ),
                acceptsInput: ContentViewModelSupport.isAudioInputURL(_:),
                preferredImportTypes: {
                    [.audio, .movie, .video, .audiovisualContent, $0].compactMap { $0 }
                }
            )
        }
    }

    func acceptsInput(_ url: URL) -> Bool {
        descriptor.acceptsInput(url)
    }

    func preferredImportTypes(mkvType: UTType?) -> [UTType] {
        descriptor.preferredImportTypes(mkvType)
    }

    func selectedOutputFormatLabel(using viewModel: ContentViewModel) -> String {
        descriptor.selectedOutputFormatLabel(viewModel)
    }

    var conversionMetadata: ContentViewModel.ConversionMetadata {
        descriptor.conversionMetadata
    }
}

extension ContentViewModel {
    func preferredImportTypes(for kind: MediaKind) -> [UTType] {
        let mkvType = FormatOptionUtilities.cachedUTType(forFilenameExtension: "mkv")
        return kind.preferredImportTypes(mkvType: mkvType)
    }

    func preferredImportTypes(for selectedTab: ConverterTab) -> [UTType] {
        guard let kind = selectedTab.mediaKind else { return [.item] }
        return preferredImportTypes(for: kind)
    }

    func requestFileImport() {
        isImporting = true
    }
}
