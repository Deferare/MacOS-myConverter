import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    struct MediaDescriptor {
        let sidebarSystemImage: String
        let usesFilledInputSystemImage: Bool
        let acceptsInput: (URL) -> Bool
        let preferredImportTypes: (UTType?) -> [UTType]
    }
}

extension ContentViewModel.MediaKind {
    var descriptor: ContentViewModel.MediaDescriptor {
        switch self {
        case .video:
            return ContentViewModel.MediaDescriptor(
                sidebarSystemImage: "film",
                usesFilledInputSystemImage: true,
                acceptsInput: ContentViewModelSupport.isVideoInputURL(_:),
                preferredImportTypes: { [.movie, .video, $0].compactMap { $0 } }
            )
        case .image:
            return ContentViewModel.MediaDescriptor(
                sidebarSystemImage: "photo",
                usesFilledInputSystemImage: true,
                acceptsInput: ContentViewModelSupport.isImageInputURL(_:),
                preferredImportTypes: { _ in [.image] }
            )
        case .audio:
            return ContentViewModel.MediaDescriptor(
                sidebarSystemImage: "waveform",
                usesFilledInputSystemImage: false,
                acceptsInput: ContentViewModelSupport.isAudioInputURL(_:),
                preferredImportTypes: {
                    [.audio, .movie, .video, .audiovisualContent, $0].compactMap { $0 }
                }
            )
        }
    }

    func acceptsInput(_ url: URL) -> Bool {
        descriptor.acceptsInput(url)
    }

    func preferredImportTypes(mkvType: UTType?) -> [UTType] {
        descriptor.preferredImportTypes(mkvType)
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
