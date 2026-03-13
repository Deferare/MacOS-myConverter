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

    struct MediaDescriptor {
        let sidebarSystemImage: String
        let outputDirectoryURL: ReferenceWritableKeyPath<ContentViewModel, URL?>
        let selectedOutputFormatLabel: (ContentViewModel) -> String
        let saveSettingsFailureContext: String
        let loadSettingsFailureContext: String
        let conversionMetadata: ConversionMetadata
        let acceptsInput: (URL) -> Bool
        let preferredImportTypes: (UTType?) -> [UTType]
        let availableImportSources: [ContentViewModel.ImportSource]
        let iosImportDescriptor: IOSImportDescriptor
    }
}

extension ContentViewModel.MediaKind {
    private static func makeMediaDescriptor(
        sidebarSystemImage: String,
        outputDirectoryURL: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        selectedOutputFormatLabel: @escaping (ContentViewModel) -> String,
        saveSettingsFailureContext: String,
        loadSettingsFailureContext: String,
        conversionMetadata: ContentViewModel.ConversionMetadata,
        acceptsInput: @escaping (URL) -> Bool,
        preferredImportTypes: @escaping (UTType?) -> [UTType],
        availableImportSources: [ContentViewModel.ImportSource],
        iosImportDescriptor: ContentViewModel.IOSImportDescriptor
    ) -> ContentViewModel.MediaDescriptor {
        ContentViewModel.MediaDescriptor(
            sidebarSystemImage: sidebarSystemImage,
            outputDirectoryURL: outputDirectoryURL,
            selectedOutputFormatLabel: selectedOutputFormatLabel,
            saveSettingsFailureContext: saveSettingsFailureContext,
            loadSettingsFailureContext: loadSettingsFailureContext,
            conversionMetadata: conversionMetadata,
            acceptsInput: acceptsInput,
            preferredImportTypes: preferredImportTypes,
            availableImportSources: availableImportSources,
            iosImportDescriptor: iosImportDescriptor
        )
    }

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

    private static let videoDescriptor = makeMediaDescriptor(
            sidebarSystemImage: "film",
            outputDirectoryURL: \.selectedVideoOutputDirectoryURL,
            selectedOutputFormatLabel: { viewModel in
                viewModel.selectedOutputFormatLabel(using: ContentViewModel.videoOutputFormatDescriptorValue)
            },
            saveSettingsFailureContext: "Failed to persist video settings",
            loadSettingsFailureContext: "Failed to load persisted video settings",
            conversionMetadata: videoConversionMetadata,
            acceptsInput: ContentViewModelSupport.isVideoInputURL(_:),
            preferredImportTypes: { [.movie, .video, $0].compactMap { $0 } },
            availableImportSources: [.photoLibrary, .files],
            iosImportDescriptor: videoIOSImportDescriptor
        )

    private static let imageDescriptor = makeMediaDescriptor(
            sidebarSystemImage: "photo",
            outputDirectoryURL: \.selectedImageOutputDirectoryURL,
            selectedOutputFormatLabel: { viewModel in
                viewModel.selectedOutputFormatLabel(using: ContentViewModel.imageOutputFormatDescriptorValue)
            },
            saveSettingsFailureContext: "Failed to persist image settings",
            loadSettingsFailureContext: "Failed to load persisted image settings",
            conversionMetadata: imageConversionMetadata,
            acceptsInput: ContentViewModelSupport.isImageInputURL(_:),
            preferredImportTypes: { _ in [.image] },
            availableImportSources: [.photoLibrary, .files],
            iosImportDescriptor: imageIOSImportDescriptor
        )

    private static let audioDescriptor = makeMediaDescriptor(
            sidebarSystemImage: "waveform",
            outputDirectoryURL: \.selectedAudioOutputDirectoryURL,
            selectedOutputFormatLabel: { viewModel in
                viewModel.selectedOutputFormatLabel(using: ContentViewModel.audioOutputFormatDescriptorValue)
            },
            saveSettingsFailureContext: "Failed to persist audio settings",
            loadSettingsFailureContext: "Failed to load persisted audio settings",
            conversionMetadata: audioConversionMetadata,
            acceptsInput: ContentViewModelSupport.isAudioInputURL(_:),
            preferredImportTypes: {
                [.audio, .movie, .video, .audiovisualContent, $0].compactMap { $0 }
            },
            availableImportSources: [.files],
            iosImportDescriptor: audioIOSImportDescriptor
        )

    private static let descriptorsByKind: [Self: ContentViewModel.MediaDescriptor] = [
        .video: videoDescriptor,
        .image: imageDescriptor,
        .audio: audioDescriptor
    ]

    var descriptor: ContentViewModel.MediaDescriptor {
        Self.descriptorsByKind[self] ?? Self.videoDescriptor
    }

    var conversionMetadata: ContentViewModel.ConversionMetadata {
        descriptor.conversionMetadata
    }
}

extension ContentViewModel {
    private static let mkvImportType = FormatOptionUtilities.cachedUTType(forFilenameExtension: "mkv")

    func preferredImportTypes(for kind: MediaKind) -> [UTType] {
        kind.descriptor.preferredImportTypes(Self.mkvImportType)
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
        descriptor.iosImportDescriptor.photoLibraryFilter.pickerFilter
    }

    var preferredPhotoLibraryItemTypeIdentifiers: [String] {
        descriptor.iosImportDescriptor.preferredPhotoLibraryItemTypeIdentifiers
    }

    var temporaryImportFallbackFileExtension: String {
        descriptor.iosImportDescriptor.temporaryImportFallbackFileExtension
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
        let importSources = kind.descriptor.availableImportSources
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
