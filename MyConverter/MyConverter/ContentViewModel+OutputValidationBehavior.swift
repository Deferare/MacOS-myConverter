import Foundation

extension ContentViewModel.MediaKind {
    func compatibilityHintMessage(in viewModel: ContentViewModel) -> String? {
        viewModel.nonEmptyMessage(compatibilityWarningMessage(in: viewModel))
    }

    func outputSettingsValidationMessage<Format>(
        in viewModel: ContentViewModel,
        formatDescriptor: ContentViewModel.OutputFormatDescriptor<Format>,
        unavailableMessage: String,
        additionalValidation: () -> String? = { nil }
    ) -> String? {
        if let compatibilityError = viewModel.nonEmptyMessage(compatibilityErrorMessage(in: viewModel)) {
            return compatibilityError
        }

        if hasSelectedSource(in: viewModel) &&
            !viewModel.isSelectedOutputFormatAvailable(using: formatDescriptor) {
            return unavailableMessage
        }

        return additionalValidation()
    }

    private struct ValidationBehavior {
        let validationMessage: (ContentViewModel) -> String?
        let hintMessage: (ContentViewModel) -> String?
        let validateSourceOutputSettings: (ContentViewModel, URL) async -> String?
        let validatePreparedSourceOutputSettings: (
            ContentViewModel,
            PreparedSourceConversion,
            ContentViewModel.BatchExecutionEnvironment
        ) async -> String?
    }

    private static let validationBehaviorByKind: [Self: ValidationBehavior] = [
        .video: ValidationBehavior(
            validationMessage: { $0.videoValidationMessage() },
            hintMessage: { _ in nil },
            validateSourceOutputSettings: { viewModel, sourceURL in
                await viewModel.validateVideoSourceOutputSettings(sourceURL)
            },
            validatePreparedSourceOutputSettings: { viewModel, source, environment in
                await viewModel.validatePreparedVideoSourceOutputSettings(
                    source: source,
                    environment: environment
                )
            }
        ),
        .image: ValidationBehavior(
            validationMessage: { $0.imageValidationMessage() },
            hintMessage: { $0.imageHintMessage() },
            validateSourceOutputSettings: { viewModel, sourceURL in
                await viewModel.validateImageSourceOutputSettings(sourceURL)
            },
            validatePreparedSourceOutputSettings: { viewModel, source, environment in
                await viewModel.validatePreparedImageSourceOutputSettings(
                    source: source,
                    environment: environment
                )
            }
        ),
        .audio: ValidationBehavior(
            validationMessage: { $0.audioValidationMessage() },
            hintMessage: { $0.audioHintMessage() },
            validateSourceOutputSettings: { viewModel, sourceURL in
                await viewModel.validateAudioSourceOutputSettings(sourceURL)
            },
            validatePreparedSourceOutputSettings: { viewModel, source, environment in
                await viewModel.validatePreparedAudioSourceOutputSettings(
                    source: source,
                    environment: environment
                )
            }
        )
    ]

    private var validationBehavior: ValidationBehavior {
        Self.validationBehaviorByKind[self] ?? Self.validationBehaviorByKind[.video]!
    }

    func validationMessage(in viewModel: ContentViewModel) -> String? {
        validationBehavior.validationMessage(viewModel)
    }

    func hintMessage(in viewModel: ContentViewModel) -> String? {
        validationBehavior.hintMessage(viewModel)
    }

    func validateSourceOutputSettings(
        in viewModel: ContentViewModel,
        sourceURL: URL
    ) async -> String? {
        await validationBehavior.validateSourceOutputSettings(viewModel, sourceURL)
    }

    func validatePreparedSourceOutputSettings(
        in viewModel: ContentViewModel,
        source: PreparedSourceConversion,
        environment: ContentViewModel.BatchExecutionEnvironment
    ) async -> String? {
        await validationBehavior.validatePreparedSourceOutputSettings(
            viewModel,
            source,
            environment
        )
    }
}
