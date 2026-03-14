import AVFoundation
import Foundation

extension VideoConversionEngine {
    static func makeSourceCapabilityCacheKey(for inputURL: URL, runtimeIdentity: String?) -> String {
        "\(OutputPathUtilities.fileFingerprint(for: inputURL))|\(runtimeIdentity ?? "none")"
    }

    static func makeVideoCapabilities(
        availableOutputFormats: [VideoFormatOption],
        warningMessage: String? = nil,
        errorMessage: String? = nil
    ) -> VideoSourceCapabilities {
        VideoSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage
        )
    }

    static func makeAudioCapabilities(
        availableOutputFormats: [AudioFormatOption],
        warningMessage: String? = nil,
        errorMessage: String? = nil
    ) -> AudioSourceCapabilities {
        AudioSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage
        )
    }
}
