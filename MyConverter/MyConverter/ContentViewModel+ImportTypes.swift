import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    func preferredImportTypes(for selectedTab: ConverterTab) -> [UTType] {
        let mkvType = UTType(filenameExtension: "mkv")

        switch selectedTab {
        case .video:
            return [.movie, .video, mkvType].compactMap { $0 }
        case .image:
            return [.image]
        case .audio:
            return [.audio, .movie, .video, .audiovisualContent, mkvType].compactMap { $0 }
        case .about:
            return [.item]
        }
    }

    func requestFileImport() {
        isImporting = true
    }
}
