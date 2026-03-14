import SwiftUI

struct ImageConverterFormSectionView: View, Equatable {
    let state: ContentViewModel.ImageFormPresentationState
    @ObservedObject private var viewModel: ContentViewModel

    init(viewModel: ContentViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        state = .init(viewModel: viewModel)
    }

    static func == (lhs: ImageConverterFormSectionView, rhs: ImageConverterFormSectionView) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        let _ = PerformanceSignpost.event("ImageFormRender")
        let showsHint = state.hintMessage != nil
        let showsQuality = state.shouldShowImageQualityOption
        let showsPNGCompression = state.shouldShowPNGCompressionOption
        let showsPreserveAnimation = state.shouldShowPreserveAnimationOption

        ConverterFormSections(
            isConverting: state.isConverting
        ) {
            MenuPicker(
                "Output Format",
                selection: viewModel.binding(to: \.imageOptionsState.selectedOutputFormat),
                options: state.outputFormatOptions,
                disabledWhenEmpty: true,
                showsDivider: true,
                label: { "\($0.displayName) (.\($0.fileExtension))" }
            )

            MenuPicker(
                "Resolution",
                selection: viewModel.binding(to: \.imageOptionsState.selectedResolution),
                options: Array(ResolutionOption.allCases),
                showsDivider: showsQuality || showsPNGCompression || showsPreserveAnimation || showsHint,
                label: { $0.rawValue }
            )

            if state.shouldShowImageQualityOption {
                MenuPicker(
                    "Quality",
                    selection: viewModel.binding(to: \.imageOptionsState.selectedQuality),
                    options: Array(ImageQualityOption.allCases),
                    showsDivider: showsPNGCompression || showsPreserveAnimation || showsHint,
                    label: { $0.rawValue }
                )
            }

            if state.shouldShowPNGCompressionOption {
                MenuPicker(
                    "PNG Compression",
                    selection: viewModel.binding(to: \.imageOptionsState.selectedPNGCompressionLevel),
                    options: Array(PNGCompressionLevelOption.allCases),
                    showsDivider: showsPreserveAnimation || showsHint,
                    label: { $0.rawValue }
                )
            }

            if state.shouldShowPreserveAnimationOption {
                ConverterToggleRow(
                    "Preserve Animation",
                    showsDivider: showsHint,
                    isOn: viewModel.binding(to: \.imageOptionsState.preserveAnimation)
                )
            }

            if let hint = state.hintMessage {
                ConverterSettingsHint(text: hint, showsDivider: false)
            }
        }
    }
}
