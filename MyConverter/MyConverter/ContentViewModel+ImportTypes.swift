import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    struct MediaInputDescriptor {
        let acceptsInput: (URL) -> Bool
        let preferredImportTypes: (UTType?) -> [UTType]
    }
}

extension ContentViewModel.MediaKind {
    var inputDescriptor: ContentViewModel.MediaInputDescriptor {
        switch self {
        case .video:
            return ContentViewModel.MediaInputDescriptor(
                acceptsInput: ContentViewModelSupport.isVideoInputURL(_:),
                preferredImportTypes: { [.movie, .video, $0].compactMap { $0 } }
            )
        case .image:
            return ContentViewModel.MediaInputDescriptor(
                acceptsInput: ContentViewModelSupport.isImageInputURL(_:),
                preferredImportTypes: { _ in [.image] }
            )
        case .audio:
            return ContentViewModel.MediaInputDescriptor(
                acceptsInput: ContentViewModelSupport.isAudioInputURL(_:),
                preferredImportTypes: {
                    [.audio, .movie, .video, .audiovisualContent, $0].compactMap { $0 }
                }
            )
        }
    }

    func acceptsInput(_ url: URL) -> Bool {
        inputDescriptor.acceptsInput(url)
    }

    func preferredImportTypes(mkvType: UTType?) -> [UTType] {
        inputDescriptor.preferredImportTypes(mkvType)
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
