import SwiftUI

struct ImageConverterFormSectionView: View, Equatable {
    let state: ContentViewModel.ImageFormPresentationState
    let bindings: ContentViewModel.ImageFormBindings

    static func == (lhs: ImageConverterFormSectionView, rhs: ImageConverterFormSectionView) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        let _ = PerformanceSignpost.event("ImageFormRender")

        ConverterFormSections(
            isConverting: state.isConverting
        ) {
            MenuPicker(
                "Output Format",
                selection: bindings.selectedOutputFormat,
                options: state.outputFormatOptions,
                disabledWhenEmpty: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            MenuPicker(
                "Resolution",
                selection: bindings.selectedResolution,
                options: Array(ResolutionOption.allCases),
                label: { $0.rawValue }
            )

            if state.shouldShowImageQualityOption {
                MenuPicker(
                    "Quality",
                    selection: bindings.selectedQuality,
                    options: Array(ImageQualityOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if state.shouldShowPNGCompressionOption {
                MenuPicker(
                    "PNG Compression",
                    selection: bindings.selectedPNGCompressionLevel,
                    options: Array(PNGCompressionLevelOption.allCases),
                    label: { $0.rawValue }
                )
            }

            if state.shouldShowPreserveAnimationOption {
                ConverterToggleRow("Preserve Animation", isOn: bindings.preserveAnimation)
            }

            if let hint = state.hintMessage {
                ConverterSettingsHint(text: hint)
            }
        }
    }
}
