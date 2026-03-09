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

    var settingsState = PersistedSettingsState()
    var taskState = TaskState()
    var capabilityWarmState = CapabilityWarmState()

    init() {
        loadPersistedSourceSettingsState()
        applyPlaceholderCapabilityState()
    }
}
