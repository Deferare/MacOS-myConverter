import Combine
import Foundation

enum ConverterTab: String, CaseIterable, Identifiable {
    case video
    case audio
    case image
    case about

    var id: String { rawValue }

    var title: String { mediaKind?.sidebarTitle ?? "About" }

    var systemImage: String { mediaKind?.sidebarSystemImage ?? "info.circle" }
}

@MainActor
final class ContentViewModel: ObservableObject {
    enum ConversionStatusLevel {
        case normal
        case warning
        case error
    }

    @Published var videoRuntimeState = VideoRuntimeState()
    @Published var imageRuntimeState = ImageRuntimeState()
    @Published var audioRuntimeState = AudioRuntimeState()
    @Published var videoOptionsState = VideoOptionsState()
    @Published var imageOptionsState = ImageOptionsState()
    @Published var audioOptionsState = AudioOptionsState()

    @Published var isImporting = false

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
