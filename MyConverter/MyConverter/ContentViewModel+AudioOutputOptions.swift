import Foundation

extension ContentViewModel {
    var audioOutputFormatOptions: [AudioFormatOption] {
        availableOutputFormatOptions(using: Self.audioOutputFormatDescriptorValue)
    }

    var audioOutputEncoderOptions: [AudioEncoderOption] {
        audioOutputEncodingSelectionState.encoderOptions
    }

    var shouldShowAudioOutputSampleRateOption: Bool {
        audioOutputEncodingSelectionState.shouldShowSampleRateOption
    }

    var shouldShowAudioOutputBitRateOption: Bool {
        audioOutputEncodingSelectionState.shouldShowBitRateOption
    }
}
