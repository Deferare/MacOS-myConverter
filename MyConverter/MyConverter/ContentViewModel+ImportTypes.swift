import Foundation
import UniformTypeIdentifiers

extension ContentViewModel.MediaKind {
    func preferredImportTypes(mkvType: UTType?) -> [UTType] {
        switch self {
        case .video:
            return [.movie, .video, mkvType].compactMap { $0 }
        case .image:
            return [.image]
        case .audio:
            return [.audio, .movie, .video, .audiovisualContent, mkvType].compactMap { $0 }
        }
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
