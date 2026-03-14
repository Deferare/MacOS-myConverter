import Foundation

extension ContentViewModel {
    var audioOutputFormatOptions: [AudioFormatOption] {
        availableOutputFormatOptions(using: Self.audioOutputFormatDescriptorValue)
    }

    var audioOutputEncoderOptions: [AudioEncoderOption] {
        audioOutputEncoderSelectionOptions
    }

    var shouldShowAudioOutputSampleRateOption: Bool {
        selectedAudioOutputEncoder.supportsSampleRate
    }

    var shouldShowAudioOutputBitRateOption: Bool {
        selectedAudioOutputEncoder.supportsAudioBitRate
    }
}
