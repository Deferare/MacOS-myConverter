import Foundation
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

extension ContentViewModel.MediaKind {
    func preferredImportTypes() -> [UTType] {
        preferredImportTypes(mkvType: ContentViewModel.mkvImportType)
    }

    func requestFileImport(in viewModel: ContentViewModel) {
        viewModel.isImporting = true
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

    func startImport(from source: ContentViewModel.ImportSource, in viewModel: ContentViewModel) {
        viewModel.activeImportRequest = ContentViewModel.ImportRequest(kind: self, source: source)
        viewModel.isImporting = source == .files
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

    func finishActiveImportRequest() {
        activeImportRequest = nil
        isImporting = false
    }
}
#endif
