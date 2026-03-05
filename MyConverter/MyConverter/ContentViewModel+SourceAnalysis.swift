import Foundation

extension ContentViewModel {
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
