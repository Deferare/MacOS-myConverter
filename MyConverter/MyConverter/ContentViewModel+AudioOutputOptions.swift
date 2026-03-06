import Foundation

extension ContentViewModel {
    var audioOutputFormatOptions: [AudioFormatOption] {
        availableOutputFormatOptions(using: audioOutputFormatDescriptor())
    }

    var audioOutputEncoderOptions: [AudioEncoderOption] {
        resolvedOptions(availableAudioOutputEncoders) {
            if audioSourceURL == nil && selectedAudioOutputFormat.allowsFFmpegAutomaticAudioCodec {
                return [.auto]
            }
            return []
        }
    }

    var shouldShowAudioOutputSampleRateOption: Bool {
        selectedAudioOutputEncoder.supportsSampleRate
    }

    var shouldShowAudioOutputBitRateOption: Bool {
        selectedAudioOutputEncoder.supportsAudioBitRate
    }
}
