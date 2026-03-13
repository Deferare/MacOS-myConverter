import Foundation

extension ContentViewModel {
    var audioOutputFormatOptions: [AudioFormatOption] {
        availableOutputFormatOptions(using: audioOutputFormatDescriptor())
    }

    var audioOutputEncoderOptions: [AudioEncoderOption] {
        resolvedOptions(
            availableAudioOutputEncoders,
            autoOption: AudioEncoderOption.auto,
            includesAutoOption: audioSourceURL == nil &&
                selectedAudioOutputFormat.allowsFFmpegAutomaticAudioCodec
        )
    }

    var shouldShowAudioOutputSampleRateOption: Bool {
        selectedAudioOutputEncoder.supportsSampleRate
    }

    var shouldShowAudioOutputBitRateOption: Bool {
        selectedAudioOutputEncoder.supportsAudioBitRate
    }
}
