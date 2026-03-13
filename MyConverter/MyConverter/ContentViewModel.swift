import Combine
import Foundation

enum ConverterTab: String, CaseIterable, Identifiable, Hashable {
    case video
    case audio
    case image
    case about

    static let mediaTabs: [Self] = [.video, .audio, .image]
    static let appTabs: [Self] = [.about]

    var id: String { rawValue }

    var title: String { mediaKind?.sidebarTitle ?? "About" }

    var systemImage: String { mediaKind?.sidebarSystemImage ?? "info.circle" }

    init(kind: ContentViewModel.MediaKind) {
        self = Self(rawValue: kind.rawValue) ?? .video
    }
}

@MainActor
final class ContentViewModel: ObservableObject {
    enum ConversionStatusLevel {
        case normal
        case warning
        case error
    }

    enum ImportSource: String, CaseIterable, Identifiable {
        case files
        case photoLibrary

        private static let buttonTitles: [Self: String] = [
            .files: "Files",
            .photoLibrary: "Photo Library"
        ]

        var id: String { rawValue }

        var buttonTitle: String { Self.buttonTitles[self] ?? rawValue.capitalized }
    }

    struct ImportRequest: Equatable, Identifiable {
        let kind: MediaKind
        let source: ImportSource

        var id: String {
            "\(kind.rawValue)-\(source.rawValue)"
        }
    }

    @Published var videoRuntimeState = VideoRuntimeState()
    @Published var imageRuntimeState = ImageRuntimeState()
    @Published var audioRuntimeState = AudioRuntimeState()
    @Published var videoOptionsState = VideoOptionsState()
    @Published var imageOptionsState = ImageOptionsState()
    @Published var audioOptionsState = AudioOptionsState()

    @Published var isImporting = false
    @Published var activeImportRequest: ImportRequest?

    let services: PlatformServices
    var settingsState = PersistedSettingsState()
    var taskState = TaskState()
    var capabilityWarmState = CapabilityWarmState()
    var selectionPreparationState = SelectionPreparationState()
    var securityScopeState = SecurityScopeState()

    init(services: PlatformServices) {
        self.services = services
        loadPersistedSourceSettingsState()
        applyPlaceholderCapabilityState()
    }

    convenience init() {
        self.init(services: .makeDefault())
    }

    deinit {
        let retained = securityScopeState.retainedByPath.values
        for entry in retained where entry.shouldStopAccessing {
            entry.url.stopAccessingSecurityScopedResource()
        }
    }
}
