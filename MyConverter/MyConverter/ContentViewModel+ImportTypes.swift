import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    func preferredImportTypes(for kind: MediaKind) -> [UTType] {
        let mkvType = UTType(filenameExtension: "mkv")

        switch kind {
        case .video:
            return [.movie, .video, mkvType].compactMap { $0 }
        case .image:
            return [.image]
        case .audio:
            return [.audio, .movie, .video, .audiovisualContent, mkvType].compactMap { $0 }
        }
    }

    func preferredImportTypes(for selectedTab: ConverterTab) -> [UTType] {
        guard let kind = mediaKind(for: selectedTab) else { return [.item] }
        return preferredImportTypes(for: kind)
    }

    func requestFileImport() {
        isImporting = true
    }
}
