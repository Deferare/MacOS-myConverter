import Foundation
import UniformTypeIdentifiers

extension ContentViewModel.MediaKind {
    var sidebarSystemImage: String {
        importMetadata.sidebarSystemImage
    }

    var outputDirectoryURLKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?> {
        importMetadata.outputDirectoryURLKeyPath
    }

    func selectedOutputFormatLabel(in viewModel: ContentViewModel) -> String {
        importMetadata.selectedOutputFormatLabel(viewModel)
    }

    var saveSettingsFailureContext: String {
        importMetadata.saveSettingsFailureContext
    }

    var loadSettingsFailureContext: String {
        importMetadata.loadSettingsFailureContext
    }

    var outputLabel: String {
        importMetadata.outputLabel
    }

    var missingSourceLog: String {
        importMetadata.missingSourceLog
    }

    var destinationErrorCode: Int {
        importMetadata.destinationErrorCode
    }

    var skippedSummaryPrefix: String {
        importMetadata.skippedSummaryPrefix
    }

    var treatExportCancellationAsCancelled: Bool {
        importMetadata.treatExportCancellationAsCancelled
    }

    var errorLogPrefix: String {
        importMetadata.errorLogPrefix
    }

    var includeDebugInfo: Bool {
        importMetadata.includeDebugInfo
    }

    func acceptsInput(_ url: URL) -> Bool {
        importMetadata.acceptsInput(url)
    }

    func preferredImportTypes(mkvType: UTType?) -> [UTType] {
        importMetadata.preferredImportTypes(mkvType)
    }

    var availableImportSources: [ContentViewModel.ImportSource] {
        importMetadata.availableImportSources
    }

    var defaultImportSource: ContentViewModel.ImportSource? {
        availableImportSources.first(where: { $0 == .files }) ?? availableImportSources.first
    }

    var photoLibraryFilter: ContentViewModel.IOSPhotoLibraryFilter {
        importMetadata.photoLibraryFilter
    }

    var preferredPhotoLibraryItemTypeIdentifiers: [String] {
        importMetadata.preferredPhotoLibraryItemTypeIdentifiers
    }

    var temporaryImportFallbackFileExtension: String {
        importMetadata.temporaryImportFallbackFileExtension
    }
}
