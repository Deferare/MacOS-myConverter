import Combine
import Foundation

enum ConverterTab: String, CaseIterable, Identifiable {
    case video
    case audio
    case image
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video:
            return "Video"
        case .image:
            return "Image"
        case .audio:
            return "Audio"
        case .about:
            return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .video:
            return "film"
        case .image:
            return "photo"
        case .audio:
            return "waveform"
        case .about:
            return "info.circle"
        }
    }
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

    init() {
        settingsState.videoSettingsBySourceID = loadPersistedSourceSettings(using: videoSettingsDescriptor())
        settingsState.imageSettingsBySourceID = loadPersistedSourceSettings(using: imageSettingsDescriptor())
        settingsState.audioSettingsBySourceID = loadPersistedSourceSettings(using: audioSettingsDescriptor())
        applyPlaceholderCapabilityState()
    }
}
