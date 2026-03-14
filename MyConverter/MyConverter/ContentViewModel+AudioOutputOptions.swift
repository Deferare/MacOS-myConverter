import Foundation

extension ContentViewModel {
    var audioOutputFormatOptions: [AudioFormatOption] {
        availableOutputFormatOptions(using: Self.audioOutputFormatDescriptor)
    }

    var audioOutputEncoderOptions: [AudioEncoderOption] {
        audioOutputEncodingSelectionState.encoderOptions
    }

    var shouldShowAudioOutputSampleRateOption: Bool {
        audioOptionsState.selectedOutputEncoder.supportsSampleRate
    }

    var shouldShowAudioOutputBitRateOption: Bool {
        audioOptionsState.selectedOutputEncoder.supportsAudioBitRate
    }
}
