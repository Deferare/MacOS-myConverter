import Foundation

extension ContentViewModel {
    // MARK: - Conversion Control

    func startConversion() {
        launchConversionTask(&conversionTask, isRunning: isConverting) { [weak self] in
            await self?.convert()
        }
    }

    func cancelConversion() {
        cancelConversionTask(conversionTask, isRunning: isConverting)
    }

    func startImageConversion() {
        launchConversionTask(&imageConversionTask, isRunning: isImageConverting) { [weak self] in
            await self?.convertImage()
        }
    }

    func cancelImageConversion() {
        cancelConversionTask(imageConversionTask, isRunning: isImageConverting)
    }

    func startAudioConversion() {
        launchConversionTask(&audioConversionTask, isRunning: isAudioConverting) { [weak self] in
            await self?.convertAudio()
        }
    }

    func cancelAudioConversion() {
        cancelConversionTask(audioConversionTask, isRunning: isAudioConverting)
    }

    func launchConversionTask(
        _ task: inout Task<Void, Never>?,
        isRunning: Bool,
        operation: @escaping @MainActor () async -> Void
    ) {
        guard !isRunning else { return }
        task = Task {
            await operation()
        }
    }

    func cancelConversionTask(_ task: Task<Void, Never>?, isRunning: Bool) {
        guard isRunning else { return }
        task?.cancel()
    }

    struct AggregatedSourceCapabilities<Format> {
        var commonFormats: [Format] = []
        var warnings: [String] = []
        var errors: [String] = []
    }

    func aggregateSourceCapabilities<Capability, Format>(
        for selection: [URL],
        fetchCapabilities: @escaping (URL) async -> Capability,
        availableFormats: (Capability) -> [Format],
        warningMessage: (Capability) -> String?,
        errorMessage: (Capability) -> String?,
        intersect: ([Format], [Format]) -> [Format],
        onCapability: ((URL, Capability) -> Void)? = nil
    ) async -> AggregatedSourceCapabilities<Format>? {
        var isInitialized = false
        var aggregated = AggregatedSourceCapabilities<Format>()

        for source in selection {
            guard !Task.isCancelled else { return nil }

            let capabilities = await withSourceSecurityScope(for: source) {
                await fetchCapabilities(source)
            }
            onCapability?(source, capabilities)

            let formats = availableFormats(capabilities)
            if isInitialized {
                aggregated.commonFormats = intersect(aggregated.commonFormats, formats)
            } else {
                aggregated.commonFormats = formats
                isInitialized = true
            }

            if let warning = warningMessage(capabilities) {
                aggregated.warnings.append(labeledCapabilityMessage(warning, for: source, totalCount: selection.count))
            }
            if let error = errorMessage(capabilities) {
                aggregated.errors.append(labeledCapabilityMessage(error, for: source, totalCount: selection.count))
            }
        }

        guard !Task.isCancelled else { return nil }
        return aggregated
    }

    func analyzeSourceSelection<Capability, Format>(
        urls: [URL],
        analysisTaskKeyPath: ReferenceWritableKeyPath<ContentViewModel, Task<Void, Never>?>,
        isAnalyzingKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        availableFormatsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [Format]>,
        warningMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        selectedSourceIDs: @escaping () -> [String],
        resetForEmptySelection: () -> Void,
        fetchCapabilities: @escaping (URL) async -> Capability,
        availableFormats: @escaping (Capability) -> [Format],
        warningMessage: @escaping (Capability) -> String?,
        errorMessage: @escaping (Capability) -> String?,
        intersect: @escaping ([Format], [Format]) -> [Format],
        deduplicatedAndSorted: @escaping ([Format]) -> [Format],
        noCommonFormatsMessage: String,
        onCapability: ((URL, Capability) -> Void)? = nil,
        onFormatsResolved: @escaping ([Format]) -> Void
    ) {
        let selection = uniqueStandardizedURLs(urls)
        let expectedSourceIDs = selection.map(sourceIdentifier(for:))
        guard !selection.isEmpty else {
            resetForEmptySelection()
            return
        }

        self[keyPath: isAnalyzingKeyPath] = true
        self[keyPath: analysisTaskKeyPath] = Task { [weak self] in
            guard let self else { return }
            guard let aggregated = await self.aggregateSourceCapabilities(
                for: selection,
                fetchCapabilities: fetchCapabilities,
                availableFormats: availableFormats,
                warningMessage: warningMessage,
                errorMessage: errorMessage,
                intersect: intersect,
                onCapability: onCapability
            ) else {
                return
            }
            guard selectedSourceIDs() == expectedSourceIDs else { return }

            let resolvedFormats = deduplicatedAndSorted(aggregated.commonFormats)
            self[keyPath: isAnalyzingKeyPath] = false
            self[keyPath: availableFormatsKeyPath] = resolvedFormats
            self[keyPath: warningMessageKeyPath] = self.joinedCapabilityMessages(aggregated.warnings)

            if let joinedErrors = self.joinedCapabilityMessages(aggregated.errors) {
                self[keyPath: errorMessageKeyPath] = joinedErrors
            } else if selection.count > 1 && resolvedFormats.isEmpty {
                self[keyPath: errorMessageKeyPath] = noCommonFormatsMessage
            } else {
                self[keyPath: errorMessageKeyPath] = nil
            }

            onFormatsResolved(resolvedFormats)
        }
    }

    // MARK: - Video Source / Analyze

    func applySelectedVideoSources(_ urls: [URL]) {
        applySelectedSources(
            urls,
            cancelAnalysisTask: {
                cancelTask(&sourceAnalysisTask)
            },
            assignSelection: { selection in
                assignVideoSelection(selection)
            },
            resetState: {
                resetVideoConversionOutputs()
                resetVideoCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredVideoSettings(for: sourceID)
            },
            analyzeSelection: { selection in
                analyzeSourceCompatibility(for: selection)
            }
        )
    }

    func analyzeSourceCompatibility(for urls: [URL]) {
        analyzeSourceSelection(
            urls: urls,
            analysisTaskKeyPath: \.sourceAnalysisTask,
            isAnalyzingKeyPath: \.isAnalyzingSource,
            availableFormatsKeyPath: \.availableOutputFormats,
            warningMessageKeyPath: \.sourceCompatibilityWarningMessage,
            errorMessageKeyPath: \.sourceCompatibilityErrorMessage,
            selectedSourceIDs: {
                self.selectedVideoSourceURLs.map { self.sourceIdentifier(for: $0) }
            },
            resetForEmptySelection: {
                isAnalyzingSource = false
                availableOutputFormats = []
                sourceCompatibilityErrorMessage = nil
                sourceCompatibilityWarningMessage = nil
            },
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            intersect: { lhs, rhs in
                ContentViewModelSupport.intersectFormats(lhs, rhs, normalizedID: { $0.normalizedID })
            },
            deduplicatedAndSorted: { VideoFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output container is available for the selected files.",
            onFormatsResolved: { resolvedFormats in
                if let first = resolvedFormats.first,
                   !resolvedFormats.contains(where: { $0.normalizedID == self.selectedOutputFormat.normalizedID }) {
                    self.selectedOutputFormat = first
                }

                self.ensureSelectedVideoOutputFormatIsAvailable()
                self.refreshVideoCodecOptions()
                self.persistCurrentSettingsIfNeeded()
            }
        )
    }

    // MARK: - Image Source / Analyze

    func applySelectedImageSources(_ urls: [URL]) {
        applySelectedSources(
            urls,
            cancelAnalysisTask: {
                cancelTask(&imageSourceAnalysisTask)
            },
            assignSelection: { selection in
                assignImageSelection(selection)
            },
            resetState: {
                resetImageCompatibilityState(resetMetadata: true)
                resetImageConversionOutputs()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredImageSettings(for: sourceID)
            },
            analyzeSelection: { selection in
                analyzeImageSourceCompatibility(for: selection)
            }
        )
    }

    func analyzeImageSourceCompatibility(for urls: [URL]) {
        let primarySourceID = uniqueStandardizedURLs(urls).first.map(sourceIdentifier(for:))
        var primaryFrameCount = 0
        var primaryHasAlpha = false

        analyzeSourceSelection(
            urls: urls,
            analysisTaskKeyPath: \.imageSourceAnalysisTask,
            isAnalyzingKeyPath: \.isAnalyzingImageSource,
            availableFormatsKeyPath: \.availableImageOutputFormats,
            warningMessageKeyPath: \.imageSourceCompatibilityWarningMessage,
            errorMessageKeyPath: \.imageSourceCompatibilityErrorMessage,
            selectedSourceIDs: {
                self.selectedImageSourceURLs.map { self.sourceIdentifier(for: $0) }
            },
            resetForEmptySelection: {
                isAnalyzingImageSource = false
                availableImageOutputFormats = []
                imageSourceFrameCount = 0
                imageSourceHasAlpha = false
                imageSourceCompatibilityErrorMessage = nil
                imageSourceCompatibilityWarningMessage = nil
            },
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            intersect: { lhs, rhs in
                ContentViewModelSupport.intersectFormats(lhs, rhs, normalizedID: { $0.normalizedID })
            },
            deduplicatedAndSorted: { ImageFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common output format is available for the selected files.",
            onCapability: { source, capabilities in
                let sourceID = self.sourceIdentifier(for: source)
                if sourceID == primarySourceID {
                    primaryFrameCount = capabilities.frameCount
                    primaryHasAlpha = capabilities.hasAlpha
                }
            },
            onFormatsResolved: { resolvedFormats in
                self.imageSourceFrameCount = primaryFrameCount
                self.imageSourceHasAlpha = primaryHasAlpha

                if let first = resolvedFormats.first,
                   !resolvedFormats.contains(where: { $0.normalizedID == self.selectedImageOutputFormat.normalizedID }) {
                    self.selectedImageOutputFormat = first
                }

                self.ensureSelectedImageOutputFormatIsAvailable()
                self.persistCurrentImageSettingsIfNeeded()
            }
        )
    }

    // MARK: - Audio Source / Analyze

    func applySelectedAudioSources(_ urls: [URL]) {
        applySelectedSources(
            urls,
            cancelAnalysisTask: {
                cancelTask(&audioSourceAnalysisTask)
            },
            assignSelection: { selection in
                assignAudioSelection(selection)
            },
            resetState: {
                resetAudioConversionOutputs()
                resetAudioCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredAudioSettings(for: sourceID)
            },
            analyzeSelection: { selection in
                analyzeAudioSourceCompatibility(for: selection)
            }
        )
    }

    func analyzeAudioSourceCompatibility(for urls: [URL]) {
        analyzeSourceSelection(
            urls: urls,
            analysisTaskKeyPath: \.audioSourceAnalysisTask,
            isAnalyzingKeyPath: \.isAnalyzingAudioSource,
            availableFormatsKeyPath: \.availableAudioOutputFormats,
            warningMessageKeyPath: \.audioSourceCompatibilityWarningMessage,
            errorMessageKeyPath: \.audioSourceCompatibilityErrorMessage,
            selectedSourceIDs: {
                self.selectedAudioSourceURLs.map { self.sourceIdentifier(for: $0) }
            },
            resetForEmptySelection: {
                isAnalyzingAudioSource = false
                availableAudioOutputFormats = []
                audioSourceCompatibilityErrorMessage = nil
                audioSourceCompatibilityWarningMessage = nil
            },
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            warningMessage: { $0.warningMessage },
            errorMessage: { $0.errorMessage },
            intersect: { lhs, rhs in
                ContentViewModelSupport.intersectFormats(lhs, rhs, normalizedID: { $0.normalizedID })
            },
            deduplicatedAndSorted: { AudioFormatOption.deduplicatedAndSorted($0) },
            noCommonFormatsMessage: "No common audio output format is available for the selected files.",
            onFormatsResolved: { resolvedFormats in
                if let first = resolvedFormats.first,
                   !resolvedFormats.contains(where: { $0.normalizedID == self.selectedAudioOutputFormat.normalizedID }) {
                    self.selectedAudioOutputFormat = first
                }

                self.ensureSelectedAudioOutputFormatIsAvailable()
                self.refreshAudioCodecOptions()
                self.persistCurrentAudioSettingsIfNeeded()
            }
        )
    }
}
