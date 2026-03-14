import Foundation
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

extension ContentViewModel {
    enum IOSPhotoLibraryFilter {
        case images
        case videos
        case none
    }
}

extension ContentViewModel.MediaKind {
    private struct Metadata {
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

    private static let metadataByKind: [Self: Metadata] = [
        .video: Metadata(
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
        .image: Metadata(
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
        .audio: Metadata(
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

    private var metadata: Metadata {
        Self.metadataByKind[self] ?? Self.metadataByKind[.video]!
    }

    var sidebarSystemImage: String {
        metadata.sidebarSystemImage
    }

    var outputDirectoryURLKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?> {
        metadata.outputDirectoryURLKeyPath
    }

    func selectedOutputFormatLabel(in viewModel: ContentViewModel) -> String {
        metadata.selectedOutputFormatLabel(viewModel)
    }

    var saveSettingsFailureContext: String {
        metadata.saveSettingsFailureContext
    }

    var loadSettingsFailureContext: String {
        metadata.loadSettingsFailureContext
    }

    var outputLabel: String {
        metadata.outputLabel
    }

    var missingSourceLog: String {
        metadata.missingSourceLog
    }

    var destinationErrorCode: Int {
        metadata.destinationErrorCode
    }

    var skippedSummaryPrefix: String {
        metadata.skippedSummaryPrefix
    }

    var treatExportCancellationAsCancelled: Bool {
        metadata.treatExportCancellationAsCancelled
    }

    var errorLogPrefix: String {
        metadata.errorLogPrefix
    }

    var includeDebugInfo: Bool {
        metadata.includeDebugInfo
    }

    func acceptsInput(_ url: URL) -> Bool {
        metadata.acceptsInput(url)
    }

    func preferredImportTypes(mkvType: UTType?) -> [UTType] {
        metadata.preferredImportTypes(mkvType)
    }

    var availableImportSources: [ContentViewModel.ImportSource] {
        metadata.availableImportSources
    }

    var defaultImportSource: ContentViewModel.ImportSource? {
        availableImportSources.first(where: { $0 == .files }) ?? availableImportSources.first
    }

    var photoLibraryFilter: ContentViewModel.IOSPhotoLibraryFilter {
        metadata.photoLibraryFilter
    }

    var preferredPhotoLibraryItemTypeIdentifiers: [String] {
        metadata.preferredPhotoLibraryItemTypeIdentifiers
    }

    var temporaryImportFallbackFileExtension: String {
        metadata.temporaryImportFallbackFileExtension
    }
}

extension ContentViewModel {
    private static let mkvImportType = FormatOptionUtilities.cachedUTType(forFilenameExtension: "mkv")

    func preferredImportTypes(for kind: MediaKind) -> [UTType] {
        kind.preferredImportTypes(mkvType: Self.mkvImportType)
    }

    func requestFileImport() {
        isImporting = true
    }
}

#if os(iOS)
extension ContentViewModel.IOSPhotoLibraryFilter {
    private static let pickerFilters: [Self: PHPickerFilter?] = [
        .images: .images,
        .videos: .videos,
        .none: nil
    ]

    var pickerFilter: PHPickerFilter? { Self.pickerFilters[self] ?? nil }
}

extension ContentViewModel.MediaKind {
    var photoLibraryPickerFilter: PHPickerFilter? {
        photoLibraryFilter.pickerFilter
    }
}

extension ContentViewModel {
    var activeFileImportRequest: ImportRequest? {
        guard let activeImportRequest, activeImportRequest.source == .files else { return nil }
        return activeImportRequest
    }

    var activePhotoLibraryImportRequest: ImportRequest? {
        guard let activeImportRequest, activeImportRequest.source == .photoLibrary else { return nil }
        return activeImportRequest
    }

    func startImport(from source: ImportSource, for kind: MediaKind) {
        activeImportRequest = ImportRequest(kind: kind, source: source)
        isImporting = source == .files
    }

    func finishActiveImportRequest() {
        activeImportRequest = nil
        isImporting = false
    }
}
#endif
