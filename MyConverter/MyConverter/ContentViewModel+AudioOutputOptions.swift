import Foundation

extension ContentViewModel {
    var audioOutputFormatOptions: [AudioFormatOption] {
        Self.audioOutputFormatDescriptorValue.availableOptions(in: self)
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
