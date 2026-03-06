import Foundation

extension ContentViewModel {
    var videoSettingsValidationMessage: String? {
        if sourceURL != nil && requiresFFmpegForCurrentVideoSettings && !VideoConversionEngine.isFFmpegAvailable() {
            return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
        }
        if shouldShowVideoBitRateOption && selectedVideoBitRate == .custom && normalizedCustomVideoBitRateKbps == nil {
            return "Please enter an integer greater than 1 for Custom Bitrate (Kbps)."
        }
        return outputSettingsValidationMessage(
            for: .video,
            formatDescriptor: videoOutputFormatDescriptor(),
            unavailableMessage: "Selected container is not available for this source."
        ) {
            if !videoEncoderOptions.contains(selectedVideoEncoder) {
                return "Selected video encoder is not available for this format."
            }
            if shouldShowAudioSettings && !audioEncoderOptions.contains(selectedAudioEncoder) {
                return "Selected audio encoder is not available for this format."
            }
            return nil
        }
    }
}
