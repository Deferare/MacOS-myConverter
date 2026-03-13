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
        let availableImportSources: () -> [ContentViewModel.ImportSource]
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
        availableImportSources: @escaping () -> [ContentViewModel.ImportSource],
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

    private static func imageIOSImportDescriptor() -> ContentViewModel.IOSImportDescriptor {
        ContentViewModel.IOSImportDescriptor(
            photoLibraryFilter: .images,
            preferredPhotoLibraryItemTypeIdentifiers: [UTType.image.identifier],
            temporaryImportFallbackFileExtension: "jpg"
        )
    }

    private static func videoIOSImportDescriptor() -> ContentViewModel.IOSImportDescriptor {
        ContentViewModel.IOSImportDescriptor(
            photoLibraryFilter: .videos,
            preferredPhotoLibraryItemTypeIdentifiers: [
                UTType.movie.identifier,
                UTType.video.identifier,
                UTType.audiovisualContent.identifier
            ],
            temporaryImportFallbackFileExtension: "mov"
        )
    }

    private static func audioIOSImportDescriptor() -> ContentViewModel.IOSImportDescriptor {
        ContentViewModel.IOSImportDescriptor(
            photoLibraryFilter: .none,
            preferredPhotoLibraryItemTypeIdentifiers: [UTType.audio.identifier],
            temporaryImportFallbackFileExtension: "m4a"
        )
    }

    private static let videoDescriptor = makeMediaDescriptor(
            sidebarSystemImage: "film",
            outputDirectoryURL: \.selectedVideoOutputDirectoryURL,
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
            preferredImportTypes: { [.movie, .video, $0].compactMap { $0 } },
            availableImportSources: { [.photoLibrary, .files] },
            iosImportDescriptor: videoIOSImportDescriptor()
        )

    private static let imageDescriptor = makeMediaDescriptor(
            sidebarSystemImage: "photo",
            outputDirectoryURL: \.selectedImageOutputDirectoryURL,
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
            preferredImportTypes: { _ in [.image] },
            availableImportSources: { [.photoLibrary, .files] },
            iosImportDescriptor: imageIOSImportDescriptor()
        )

    private static let audioDescriptor = makeMediaDescriptor(
            sidebarSystemImage: "waveform",
            outputDirectoryURL: \.selectedAudioOutputDirectoryURL,
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
            },
            availableImportSources: { [.files] },
            iosImportDescriptor: audioIOSImportDescriptor()
        )

    var descriptor: ContentViewModel.MediaDescriptor {
        switch self {
        case .video:
            return Self.videoDescriptor
        case .image:
            return Self.imageDescriptor
        case .audio:
            return Self.audioDescriptor
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

#if os(iOS)
extension ContentViewModel.IOSPhotoLibraryFilter {
    var pickerFilter: PHPickerFilter? {
        switch self {
        case .images:
            return .images
        case .videos:
            return .videos
        case .none:
            return nil
        }
    }
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

    func availableImportSources(for kind: MediaKind) -> [ImportSource] {
        kind.descriptor.availableImportSources()
    }

    func requestImport(for kind: MediaKind) {
        let importSources = availableImportSources(for: kind)
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
