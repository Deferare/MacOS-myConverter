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
    var sidebarSystemImage: String {
        switch self {
        case .video:
            "film"
        case .image:
            "photo"
        case .audio:
            "waveform"
        }
    }

    var outputDirectoryURLKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?> {
        switch self {
        case .video:
            \.videoOptionsState.selectedOutputDirectoryURL
        case .image:
            \.imageOptionsState.selectedOutputDirectoryURL
        case .audio:
            \.audioOptionsState.selectedOutputDirectoryURL
        }
    }

    func selectedOutputFormatLabel(in viewModel: ContentViewModel) -> String {
        switch self {
        case .video:
            ContentViewModel.videoOutputFormatDescriptorValue.selectedFormatLabel(in: viewModel)
        case .image:
            ContentViewModel.imageOutputFormatDescriptorValue.selectedFormatLabel(in: viewModel)
        case .audio:
            ContentViewModel.audioOutputFormatDescriptorValue.selectedFormatLabel(in: viewModel)
        }
    }

    var saveSettingsFailureContext: String {
        switch self {
        case .video:
            "Failed to persist video settings"
        case .image:
            "Failed to persist image settings"
        case .audio:
            "Failed to persist audio settings"
        }
    }

    var loadSettingsFailureContext: String {
        switch self {
        case .video:
            "Failed to load persisted video settings"
        case .image:
            "Failed to load persisted image settings"
        case .audio:
            "Failed to load persisted audio settings"
        }
    }

    var outputLabel: String {
        switch self {
        case .video:
            "Video"
        case .image:
            "Image"
        case .audio:
            "Audio"
        }
    }

    var missingSourceLog: String {
        switch self {
        case .video:
            "No file to convert."
        case .image:
            "No image file to convert."
        case .audio:
            "No audio file to convert."
        }
    }

    var destinationErrorCode: Int {
        switch self {
        case .video:
            -1001
        case .image:
            -1002
        case .audio:
            -1003
        }
    }

    var skippedSummaryPrefix: String {
        switch self {
        case .video:
            "Some video files were skipped:"
        case .image:
            "Some image files were skipped:"
        case .audio:
            "Some audio files were skipped:"
        }
    }

    var treatExportCancellationAsCancelled: Bool {
        switch self {
        case .video, .audio:
            true
        case .image:
            false
        }
    }

    var errorLogPrefix: String {
        switch self {
        case .video:
            "Conversion failed"
        case .image:
            "Image conversion failed"
        case .audio:
            "Audio conversion failed"
        }
    }

    var includeDebugInfo: Bool {
        switch self {
        case .video:
            true
        case .image, .audio:
            false
        }
    }

    func acceptsInput(_ url: URL) -> Bool {
        switch self {
        case .video:
            ContentViewModelSupport.isVideoInputURL(url)
        case .image:
            ContentViewModelSupport.isImageInputURL(url)
        case .audio:
            ContentViewModelSupport.isAudioInputURL(url)
        }
    }

    func preferredImportTypes(mkvType: UTType?) -> [UTType] {
        switch self {
        case .video:
            [.movie, .video, mkvType].compactMap { $0 }
        case .image:
            [.image]
        case .audio:
            [.audio, .movie, .video, .audiovisualContent, mkvType].compactMap { $0 }
        }
    }

    var availableImportSources: [ContentViewModel.ImportSource] {
        switch self {
        case .video, .image:
            [.photoLibrary, .files]
        case .audio:
            [.files]
        }
    }

    var photoLibraryFilter: ContentViewModel.IOSPhotoLibraryFilter {
        switch self {
        case .video:
            .videos
        case .image:
            .images
        case .audio:
            .none
        }
    }

    var preferredPhotoLibraryItemTypeIdentifiers: [String] {
        switch self {
        case .video:
            [
                UTType.movie.identifier,
                UTType.video.identifier,
                UTType.audiovisualContent.identifier
            ]
        case .image:
            [UTType.image.identifier]
        case .audio:
            [UTType.audio.identifier]
        }
    }

    var temporaryImportFallbackFileExtension: String {
        switch self {
        case .video:
            "mov"
        case .image:
            "jpg"
        case .audio:
            "m4a"
        }
    }
}

extension ContentViewModel {
    private static let mkvImportType = FormatOptionUtilities.cachedUTType(forFilenameExtension: "mkv")

    func preferredImportTypes(for kind: MediaKind) -> [UTType] {
        kind.preferredImportTypes(mkvType: Self.mkvImportType)
    }

    func preferredImportTypes(for selectedTab: ConverterTab) -> [UTType] {
        guard let kind = selectedTab.mediaKind else { return [.item] }
        return preferredImportTypes(for: kind)
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

    func requestImport(for kind: MediaKind) {
        let importSources = kind.availableImportSources
        guard let fallbackSource = importSources.first(where: { $0 == .files })
            ?? importSources.first else {
            return
        }

        activeImportRequest = nil
        isImporting = false
        startImport(from: fallbackSource, for: kind)
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
