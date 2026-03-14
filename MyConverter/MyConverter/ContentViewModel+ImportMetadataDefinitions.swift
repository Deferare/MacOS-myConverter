import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    enum IOSPhotoLibraryFilter {
        case images
        case videos
        case none
    }

    static let mkvImportType = FormatOptionUtilities.cachedUTType(forFilenameExtension: "mkv")
}

extension ContentViewModel.MediaKind {
    struct ImportMetadata {
        let sidebarSystemImage: String
        let outputDirectoryURLKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let selectedOutputFormatLabel: (ContentViewModel) -> String
        let saveSettingsFailureContext: String
        let loadSettingsFailureContext: String
        let outputLabel: String
        let missingSourceLog: String
        let destinationErrorCode: Int
        let skippedSummaryPrefix: String
        let treatExportCancellationAsCancelled: Bool
        let errorLogPrefix: String
        let includeDebugInfo: Bool
        let acceptsInput: (URL) -> Bool
        let preferredImportTypes: (UTType?) -> [UTType]
        let availableImportSources: [ContentViewModel.ImportSource]
        let photoLibraryFilter: ContentViewModel.IOSPhotoLibraryFilter
        let preferredPhotoLibraryItemTypeIdentifiers: [String]
        let temporaryImportFallbackFileExtension: String
    }

    static let importMetadataByKind: [Self: ImportMetadata] = [
        .video: ImportMetadata(
            sidebarSystemImage: "film",
            outputDirectoryURLKeyPath: \.videoOptionsState.selectedOutputDirectoryURL,
            selectedOutputFormatLabel: {
                $0.selectedOutputFormatLabel(using: ContentViewModel.videoOutputFormatDescriptor)
            },
            saveSettingsFailureContext: "Failed to persist video settings",
            loadSettingsFailureContext: "Failed to load persisted video settings",
            outputLabel: "Video",
            missingSourceLog: "No file to convert.",
            destinationErrorCode: -1001,
            skippedSummaryPrefix: "Some video files were skipped:",
            treatExportCancellationAsCancelled: true,
            errorLogPrefix: "Conversion failed",
            includeDebugInfo: true,
            acceptsInput: { ContentViewModelSupport.isVideoInputURL($0) },
            preferredImportTypes: { mkvType in
                [.movie, .video, mkvType].compactMap { $0 }
            },
            availableImportSources: [.photoLibrary, .files],
            photoLibraryFilter: .videos,
            preferredPhotoLibraryItemTypeIdentifiers: [
                UTType.movie.identifier,
                UTType.video.identifier,
                UTType.audiovisualContent.identifier
            ],
            temporaryImportFallbackFileExtension: "mov"
        ),
        .image: ImportMetadata(
            sidebarSystemImage: "photo",
            outputDirectoryURLKeyPath: \.imageOptionsState.selectedOutputDirectoryURL,
            selectedOutputFormatLabel: {
                $0.selectedOutputFormatLabel(using: ContentViewModel.imageOutputFormatDescriptor)
            },
            saveSettingsFailureContext: "Failed to persist image settings",
            loadSettingsFailureContext: "Failed to load persisted image settings",
            outputLabel: "Image",
            missingSourceLog: "No image file to convert.",
            destinationErrorCode: -1002,
            skippedSummaryPrefix: "Some image files were skipped:",
            treatExportCancellationAsCancelled: false,
            errorLogPrefix: "Image conversion failed",
            includeDebugInfo: false,
            acceptsInput: { ContentViewModelSupport.isImageInputURL($0) },
            preferredImportTypes: { _ in [.image] },
            availableImportSources: [.photoLibrary, .files],
            photoLibraryFilter: .images,
            preferredPhotoLibraryItemTypeIdentifiers: [UTType.image.identifier],
            temporaryImportFallbackFileExtension: "jpg"
        ),
        .audio: ImportMetadata(
            sidebarSystemImage: "waveform",
            outputDirectoryURLKeyPath: \.audioOptionsState.selectedOutputDirectoryURL,
            selectedOutputFormatLabel: {
                $0.selectedOutputFormatLabel(using: ContentViewModel.audioOutputFormatDescriptor)
            },
            saveSettingsFailureContext: "Failed to persist audio settings",
            loadSettingsFailureContext: "Failed to load persisted audio settings",
            outputLabel: "Audio",
            missingSourceLog: "No audio file to convert.",
            destinationErrorCode: -1003,
            skippedSummaryPrefix: "Some audio files were skipped:",
            treatExportCancellationAsCancelled: true,
            errorLogPrefix: "Audio conversion failed",
            includeDebugInfo: false,
            acceptsInput: { ContentViewModelSupport.isAudioInputURL($0) },
            preferredImportTypes: { mkvType in
                [.audio, .movie, .video, .audiovisualContent, mkvType].compactMap { $0 }
            },
            availableImportSources: [.files],
            photoLibraryFilter: .none,
            preferredPhotoLibraryItemTypeIdentifiers: [UTType.audio.identifier],
            temporaryImportFallbackFileExtension: "m4a"
        )
    ]

    var importMetadata: ImportMetadata {
        Self.importMetadataByKind[self] ?? Self.importMetadataByKind[.video]!
    }
}
