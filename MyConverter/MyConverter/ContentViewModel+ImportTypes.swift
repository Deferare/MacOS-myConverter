import Foundation
import UniformTypeIdentifiers

extension ContentViewModel {
    struct MediaDescriptor {
        let sidebarSystemImage: String
        let usesFilledInputSystemImage: Bool
        let selectedOutputFormatLabel: (ContentViewModel) -> String
        let saveSettingsFailureContext: String
        let loadSettingsFailureContext: String
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
                selectedOutputFormatLabel: { viewModel in
                    "\(viewModel.selectedOutputFormat.displayName) (.\(viewModel.selectedOutputFormat.fileExtension))"
                },
                saveSettingsFailureContext: "Failed to persist video settings",
                loadSettingsFailureContext: "Failed to load persisted video settings",
                acceptsInput: ContentViewModelSupport.isVideoInputURL(_:),
                preferredImportTypes: { [.movie, .video, $0].compactMap { $0 } }
            )
        case .image:
            return ContentViewModel.MediaDescriptor(
                sidebarSystemImage: "photo",
                usesFilledInputSystemImage: true,
                selectedOutputFormatLabel: { viewModel in
                    "\(viewModel.selectedImageOutputFormat.displayName) (.\(viewModel.selectedImageOutputFormat.fileExtension))"
                },
                saveSettingsFailureContext: "Failed to persist image settings",
                loadSettingsFailureContext: "Failed to load persisted image settings",
                acceptsInput: ContentViewModelSupport.isImageInputURL(_:),
                preferredImportTypes: { _ in [.image] }
            )
        case .audio:
            return ContentViewModel.MediaDescriptor(
                sidebarSystemImage: "waveform",
                usesFilledInputSystemImage: false,
                selectedOutputFormatLabel: { viewModel in
                    "\(viewModel.selectedAudioOutputFormat.displayName) (.\(viewModel.selectedAudioOutputFormat.fileExtension))"
                },
                saveSettingsFailureContext: "Failed to persist audio settings",
                loadSettingsFailureContext: "Failed to load persisted audio settings",
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

    func selectedOutputFormatLabel(using viewModel: ContentViewModel) -> String {
        descriptor.selectedOutputFormatLabel(viewModel)
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
