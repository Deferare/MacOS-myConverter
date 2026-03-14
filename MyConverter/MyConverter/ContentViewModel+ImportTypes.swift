import Foundation
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

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

    enum IOSPhotoLibraryFilter {
        case images
        case videos
        case none
    }

    struct IOSImportDescriptor {
        let photoLibraryFilter: IOSPhotoLibraryFilter
        let preferredPhotoLibraryItemTypeIdentifiers: [String]
        let temporaryImportFallbackFileExtension: String
    }
}

extension ContentViewModel.MediaKind {
    private static let imageIOSImportDescriptor = ContentViewModel.IOSImportDescriptor(
        photoLibraryFilter: .images,
        preferredPhotoLibraryItemTypeIdentifiers: [UTType.image.identifier],
        temporaryImportFallbackFileExtension: "jpg"
    )

    private static let videoIOSImportDescriptor = ContentViewModel.IOSImportDescriptor(
        photoLibraryFilter: .videos,
        preferredPhotoLibraryItemTypeIdentifiers: [
            UTType.movie.identifier,
            UTType.video.identifier,
            UTType.audiovisualContent.identifier
        ],
        temporaryImportFallbackFileExtension: "mov"
    )

    private static let audioIOSImportDescriptor = ContentViewModel.IOSImportDescriptor(
        photoLibraryFilter: .none,
        preferredPhotoLibraryItemTypeIdentifiers: [UTType.audio.identifier],
        temporaryImportFallbackFileExtension: "m4a"
    )

    private static let videoConversionMetadata = ContentViewModel.ConversionMetadata(
        outputLabel: "Video",
        missingSourceLog: "No file to convert.",
        destinationErrorCode: -1001,
        skippedSummaryPrefix: "Some video files were skipped:",
        treatExportCancellationAsCancelled: true,
        errorLogPrefix: "Conversion failed",
        includeDebugInfo: true
    )

    private static let imageConversionMetadata = ContentViewModel.ConversionMetadata(
        outputLabel: "Image",
        missingSourceLog: "No image file to convert.",
        destinationErrorCode: -1002,
        skippedSummaryPrefix: "Some image files were skipped:",
        treatExportCancellationAsCancelled: false,
        errorLogPrefix: "Image conversion failed",
        includeDebugInfo: false
    )

    private static let audioConversionMetadata = ContentViewModel.ConversionMetadata(
        outputLabel: "Audio",
        missingSourceLog: "No audio file to convert.",
        destinationErrorCode: -1003,
        skippedSummaryPrefix: "Some audio files were skipped:",
        treatExportCancellationAsCancelled: true,
        errorLogPrefix: "Audio conversion failed",
        includeDebugInfo: false
    )

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
            viewModel.selectedOutputFormatLabel(using: ContentViewModel.videoOutputFormatDescriptorValue)
        case .image:
            viewModel.selectedOutputFormatLabel(using: ContentViewModel.imageOutputFormatDescriptorValue)
        case .audio:
            viewModel.selectedOutputFormatLabel(using: ContentViewModel.audioOutputFormatDescriptorValue)
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

    var conversionMetadata: ContentViewModel.ConversionMetadata {
        switch self {
        case .video:
            Self.videoConversionMetadata
        case .image:
            Self.imageConversionMetadata
        case .audio:
            Self.audioConversionMetadata
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

    var iosImportDescriptor: ContentViewModel.IOSImportDescriptor {
        switch self {
        case .video:
            Self.videoIOSImportDescriptor
        case .image:
            Self.imageIOSImportDescriptor
        case .audio:
            Self.audioIOSImportDescriptor
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
        iosImportDescriptor.photoLibraryFilter.pickerFilter
    }

    var preferredPhotoLibraryItemTypeIdentifiers: [String] {
        iosImportDescriptor.preferredPhotoLibraryItemTypeIdentifiers
    }

    var temporaryImportFallbackFileExtension: String {
        iosImportDescriptor.temporaryImportFallbackFileExtension
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
