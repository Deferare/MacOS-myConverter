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

    // MARK: - Build Settings

    func buildVideoOutputSettings() throws -> VideoOutputSettings {
        let videoBitRateKbps: Int?
        if shouldShowVideoBitRateOption {
            switch selectedVideoBitRate {
            case .auto:
                videoBitRateKbps = nil
            case .custom:
                guard let custom = normalizedCustomVideoBitRateKbps else {
                    throw ConversionError.invalidCustomVideoBitRate(customVideoBitRate)
                }
                videoBitRateKbps = custom
            default:
                videoBitRateKbps = selectedVideoBitRate.kbps
            }
        } else {
            videoBitRateKbps = nil
        }

        return VideoOutputSettings(
            containerFormat: selectedOutputFormat,
            videoCodecCandidates: selectedVideoEncoder.codecCandidates,
            useHEVCTag: selectedVideoEncoder.usesHEVCCodec,
            resolution: selectedResolution.dimensions,
            frameRate: selectedFrameRate.fps,
            gifPlaybackSpeed: shouldShowGIFPlaybackSpeedOption ? selectedGIFPlaybackSpeed.multiplier : nil,
            videoBitRateKbps: videoBitRateKbps,
            audioCodecCandidates: shouldShowAudioSettings ? selectedAudioEncoder.codecCandidates : [],
            audioChannels: shouldShowAudioSettings ? selectedAudioMode.channelCount : nil,
            sampleRate: shouldShowAudioSampleRateOption ? selectedSampleRate.hertz : nil,
            audioBitRateKbps: shouldShowAudioBitRateOption ? selectedAudioBitRate.kbps : nil
        )
    }

    func buildImageOutputSettings() -> ImageOutputSettings {
        let compressionQuality: Double?
        if selectedImageOutputFormat.supportsCompressionQuality {
            compressionQuality = selectedImageQuality.compressionQuality
        } else {
            compressionQuality = nil
        }

        let pngCompressionLevel: Int?
        if selectedImageOutputFormat.supportsPNGCompressionLevel {
            pngCompressionLevel = selectedPNGCompressionLevel.level
        } else {
            pngCompressionLevel = nil
        }

        return ImageOutputSettings(
            containerFormat: selectedImageOutputFormat,
            resolution: selectedImageResolution.dimensions,
            compressionQuality: compressionQuality,
            pngCompressionLevel: pngCompressionLevel,
            preserveAnimation: preserveImageAnimation,
            sourceIsAnimated: imageSourceIsAnimated
        )
    }

    func buildAudioOutputSettings() -> AudioOutputSettings {
        AudioOutputSettings(
            containerFormat: selectedAudioOutputFormat,
            audioCodecCandidates: selectedAudioOutputEncoder.codecCandidates,
            audioChannels: selectedAudioOutputMode.channelCount,
            sampleRate: shouldShowAudioOutputSampleRateOption ? selectedAudioOutputSampleRate.hertz : nil,
            audioBitRateKbps: shouldShowAudioOutputBitRateOption ? selectedAudioOutputBitRate.kbps : nil
        )
    }

    // MARK: - Conversion State / Errors

    func prepareBatchStartState(
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        primaryOutputKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        outputsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>
    ) {
        self[keyPath: runningKeyPath] = true
        self[keyPath: primaryOutputKeyPath] = nil
        self[keyPath: outputsKeyPath] = []
        self[keyPath: errorMessageKeyPath] = nil
        self[keyPath: progressKeyPath] = 0
    }

    func prepareConversionStartState() {
        prepareBatchStartState(
            runningKeyPath: \.isConverting,
            primaryOutputKeyPath: \.convertedURL,
            outputsKeyPath: \.convertedURLs,
            errorMessageKeyPath: \.conversionErrorMessage,
            progressKeyPath: \.conversionProgress
        )
    }

    func prepareImageConversionStartState() {
        prepareBatchStartState(
            runningKeyPath: \.isImageConverting,
            primaryOutputKeyPath: \.convertedImageURL,
            outputsKeyPath: \.convertedImageURLs,
            errorMessageKeyPath: \.imageConversionErrorMessage,
            progressKeyPath: \.imageConversionProgress
        )
    }

    func prepareAudioConversionStartState() {
        prepareBatchStartState(
            runningKeyPath: \.isAudioConverting,
            primaryOutputKeyPath: \.convertedAudioURL,
            outputsKeyPath: \.convertedAudioURLs,
            errorMessageKeyPath: \.audioConversionErrorMessage,
            progressKeyPath: \.audioConversionProgress
        )
    }

    func appendConvertedOutput(
        _ outputURL: URL,
        primaryOutputKeyPath: ReferenceWritableKeyPath<ContentViewModel, URL?>,
        outputsKeyPath: ReferenceWritableKeyPath<ContentViewModel, [URL]>
    ) {
        self[keyPath: primaryOutputKeyPath] = outputURL
        var outputs = self[keyPath: outputsKeyPath]
        outputs.append(outputURL)
        self[keyPath: outputsKeyPath] = outputs
    }

    func applyConversionError(_ error: Error) {
        if case ConversionError.exportCancelled = error {
            conversionErrorMessage = nil
            return
        }

        conversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

        if let conversionError = error as? ConversionError {
            print("Conversion failed: \(conversionError.debugInfo)")
        } else {
            print("Conversion failed: \(error.localizedDescription)")
        }
    }

    func applyImageConversionError(_ error: Error) {
        imageConversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        print("Image conversion failed: \(imageConversionErrorMessage ?? error.localizedDescription)")
    }

    func applyAudioConversionError(_ error: Error) {
        if case ConversionError.exportCancelled = error {
            audioConversionErrorMessage = nil
            return
        }

        audioConversionErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        print("Audio conversion failed: \(audioConversionErrorMessage ?? error.localizedDescription)")
    }

    func removeProcessedVideoSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedVideoSourceURLs,
            assignSelection: assignVideoSelection(_:),
            onSelectionEmptied: {
                resetVideoCompatibilityMessages()
                isAnalyzingSource = false
                availableOutputFormats = VideoConversionEngine.defaultOutputFormats()
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    func removeProcessedImageSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedImageSourceURLs,
            assignSelection: assignImageSelection(_:),
            onSelectionEmptied: {
                resetImageCompatibilityState(resetMetadata: true)
                isAnalyzingImageSource = false
                availableImageOutputFormats = ImageConversionEngine.defaultOutputFormats()
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    func removeProcessedAudioSource(_ processedURL: URL) {
        removeProcessedSource(
            processedURL,
            from: selectedAudioSourceURLs,
            assignSelection: assignAudioSelection(_:),
            onSelectionEmptied: {
                resetAudioCompatibilityMessages()
                isAnalyzingAudioSource = false
                availableAudioOutputFormats = VideoConversionEngine.defaultAudioOutputFormats()
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }

    func validateOutputFormatAvailability<Capability, Format>(
        for sourceURL: URL,
        selectedFormatNormalizedID: String,
        unavailableMessage: String,
        fetchCapabilities: (URL) async -> Capability,
        availableFormats: (Capability) -> [Format],
        errorMessage: (Capability) -> String?,
        formatNormalizedID: (Format) -> String,
        additionalValidation: (Capability) -> String? = { _ in nil }
    ) async -> String? {
        let capabilities = await fetchCapabilities(sourceURL)
        if let error = errorMessage(capabilities) {
            return error
        }

        let isFormatAvailable = availableFormats(capabilities).contains {
            formatNormalizedID($0) == selectedFormatNormalizedID
        }
        if !isFormatAvailable {
            return unavailableMessage
        }

        if let extraValidationMessage = additionalValidation(capabilities) {
            return extraValidationMessage
        }

        return nil
    }

    func validateVideoOutputSettings(for sourceURL: URL) async -> String? {
        if requiresFFmpegForCurrentVideoSettings && !VideoConversionEngine.isFFmpegAvailable() {
            return "Selected output settings require ffmpeg. Install ffmpeg or reset advanced options to Auto/Original."
        }

        return await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedOutputFormat.normalizedID,
            unavailableMessage: "Selected container is not available for this source.",
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID }
        )
    }

    func validateImageOutputSettings(for sourceURL: URL) async -> String? {
        await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedImageOutputFormat.normalizedID,
            unavailableMessage: "Selected output format is not available for this source.",
            fetchCapabilities: { await ImageConversionEngine.sourceCapabilities(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID },
            additionalValidation: { capabilities in
                if capabilities.frameCount > 1 &&
                    preserveImageAnimation &&
                    selectedImageOutputFormat.supportsAnimation &&
                    !ImageConversionEngine.isFFmpegAvailable() {
                    return "Animated output requires ffmpeg for the selected format."
                }
                return nil
            }
        )
    }

    func validateAudioOutputSettings(for sourceURL: URL) async -> String? {
        await validateOutputFormatAvailability(
            for: sourceURL,
            selectedFormatNormalizedID: selectedAudioOutputFormat.normalizedID,
            unavailableMessage: "Selected output format is not available for this source.",
            fetchCapabilities: { await VideoConversionEngine.sourceCapabilitiesForAudio(for: $0) },
            availableFormats: { $0.availableOutputFormats },
            errorMessage: { $0.errorMessage },
            formatNormalizedID: { $0.normalizedID }
        )
    }

    func withSourceSecurityScope<T>(
        for sourceURL: URL,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await SecurityScopedResourceAccess.withAccess(to: sourceURL, operation: operation)
    }

    func prepareBatchContext(
        primarySourceURL: URL,
        queuedSourceURLs: [URL],
        fileExtension: String,
        outputLabel: String
    ) -> PreparedBatchConversionContext? {
        BatchConversionSupport.prepareContext(
            sourceURLs: [primarySourceURL] + queuedSourceURLs,
            fileExtension: fileExtension,
            outputLabel: outputLabel
        )
    }

    func runBatchConversionLoop(
        sourceURLs: [URL],
        destinationURLsBySourceID: [String: URL],
        destinationErrorCode: Int,
        validate: @escaping (URL) async -> String?,
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onBatchIndexChanged: @escaping (Int) -> Void
    ) async throws -> [String] {
        var skippedEntries: [String] = []
        let totalCount = max(sourceURLs.count, 1)

        for (index, currentSourceURL) in sourceURLs.enumerated() {
            try Task.checkCancellation()
            onBatchIndexChanged(index + 1)

            let shouldSkipSource = try await withSourceSecurityScope(for: currentSourceURL) {
                if let validationMessage = await validate(currentSourceURL) {
                    skippedEntries.append("\(currentSourceURL.lastPathComponent): \(validationMessage)")
                    onSourceProcessed(currentSourceURL)
                    return true
                }

                let destinationURL = try BatchConversionSupport.destinationURL(
                    for: currentSourceURL,
                    in: destinationURLsBySourceID,
                    errorCode: destinationErrorCode
                )

                let workingOutputURL = makeWorkingOutputURL(currentSourceURL)
                defer { BatchConversionSupport.cleanupWorkingOutputIfNeeded(workingOutputURL) }

                let output = try await runConversion(
                    currentSourceURL,
                    workingOutputURL,
                    index,
                    totalCount
                )
                try Task.checkCancellation()

                let savedURL = try BatchConversionSupport.saveConvertedOutput(from: output, to: destinationURL)
                onSavedOutput(savedURL)
                onSourceProcessed(currentSourceURL)
                return false
            }

            if shouldSkipSource {
                continue
            }
        }

        return skippedEntries
    }

    func executeBatchConversion(
        sourceURLs: [URL],
        destinationURLsBySourceID: [String: URL],
        destinationErrorCode: Int,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        validate: @escaping (URL) async -> String?,
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        self[keyPath: totalBatchCountKeyPath] = sourceURLs.count
        self[keyPath: currentBatchIndexKeyPath] = 0

        do {
            defer {
                self[keyPath: runningKeyPath] = false
                self[keyPath: currentBatchIndexKeyPath] = 0
                self[keyPath: totalBatchCountKeyPath] = 0
            }
            try Task.checkCancellation()

            let skippedEntries = try await runBatchConversionLoop(
                sourceURLs: sourceURLs,
                destinationURLsBySourceID: destinationURLsBySourceID,
                destinationErrorCode: destinationErrorCode,
                validate: validate,
                makeWorkingOutputURL: makeWorkingOutputURL,
                runConversion: runConversion,
                onSavedOutput: onSavedOutput,
                onSourceProcessed: onSourceProcessed,
                onBatchIndexChanged: { index in
                    self[keyPath: currentBatchIndexKeyPath] = index
                }
            )

            setProgress(1, at: progressKeyPath)
            if let summary = BatchConversionSupport.skippedFilesSummary(
                prefix: skippedSummaryPrefix,
                entries: skippedEntries
            ) {
                self[keyPath: errorMessageKeyPath] = summary
            }
        } catch is CancellationError {
            setProgress(0, at: progressKeyPath)
            self[keyPath: errorMessageKeyPath] = nil
        } catch ConversionError.exportCancelled where treatExportCancellationAsCancelled {
            setProgress(0, at: progressKeyPath)
            self[keyPath: errorMessageKeyPath] = nil
        } catch {
            onError(error)
        }
    }

    func performMediaBatchConversion<OutputSettings>(
        canConvert: Bool,
        primarySourceURL: URL?,
        queuedSourceURLs: [URL],
        missingSourceLog: String,
        fileExtension: String,
        outputLabel: String,
        destinationErrorCode: Int,
        runningKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        progressKeyPath: ReferenceWritableKeyPath<ContentViewModel, Double>,
        errorMessageKeyPath: ReferenceWritableKeyPath<ContentViewModel, String?>,
        currentBatchIndexKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        totalBatchCountKeyPath: ReferenceWritableKeyPath<ContentViewModel, Int>,
        skippedSummaryPrefix: String,
        treatExportCancellationAsCancelled: Bool = false,
        startState: () -> Void,
        buildOutputSettings: () throws -> OutputSettings,
        validate: @escaping (URL) async -> String?,
        makeWorkingOutputURL: @escaping (URL) -> URL,
        runConversion: @escaping (URL, URL, OutputSettings, Int, Int) async throws -> URL,
        onSavedOutput: @escaping (URL) -> Void,
        onSourceProcessed: @escaping (URL) -> Void,
        onError: (Error) -> Void
    ) async {
        guard canConvert, let primarySourceURL else {
            if primarySourceURL == nil {
                print(missingSourceLog)
            }
            return
        }

        let outputSettings: OutputSettings
        do {
            outputSettings = try buildOutputSettings()
        } catch {
            onError(error)
            return
        }

        guard let batchContext = prepareBatchContext(
            primarySourceURL: primarySourceURL,
            queuedSourceURLs: queuedSourceURLs,
            fileExtension: fileExtension,
            outputLabel: outputLabel
        ) else {
            return
        }

        let sourceURLs = batchContext.sourceURLs
        let destinationURLsBySourceID = batchContext.destinationURLsBySourceID
        defer { batchContext.stopAccessingBatchDirectory() }

        startState()
        await executeBatchConversion(
            sourceURLs: sourceURLs,
            destinationURLsBySourceID: destinationURLsBySourceID,
            destinationErrorCode: destinationErrorCode,
            runningKeyPath: runningKeyPath,
            progressKeyPath: progressKeyPath,
            errorMessageKeyPath: errorMessageKeyPath,
            currentBatchIndexKeyPath: currentBatchIndexKeyPath,
            totalBatchCountKeyPath: totalBatchCountKeyPath,
            skippedSummaryPrefix: skippedSummaryPrefix,
            treatExportCancellationAsCancelled: treatExportCancellationAsCancelled,
            validate: validate,
            makeWorkingOutputURL: makeWorkingOutputURL,
            runConversion: { sourceURL, workingOutputURL, index, totalCount in
                try await runConversion(sourceURL, workingOutputURL, outputSettings, index, totalCount)
            },
            onSavedOutput: onSavedOutput,
            onSourceProcessed: onSourceProcessed,
            onError: onError
        )
    }

    // MARK: - Video Convert

    func convert() async {
        defer { conversionTask = nil }

        await performMediaBatchConversion(
            canConvert: canConvert,
            primarySourceURL: sourceURL,
            queuedSourceURLs: queuedSourceURLs,
            missingSourceLog: "No file to convert.",
            fileExtension: selectedOutputFormat.fileExtension,
            outputLabel: "Video",
            destinationErrorCode: -1001,
            runningKeyPath: \.isConverting,
            progressKeyPath: \.conversionProgress,
            errorMessageKeyPath: \.conversionErrorMessage,
            currentBatchIndexKeyPath: \.currentVideoBatchIndex,
            totalBatchCountKeyPath: \.totalVideoBatchCount,
            skippedSummaryPrefix: "Some video files were skipped:",
            treatExportCancellationAsCancelled: true,
            startState: { self.prepareConversionStartState() },
            buildOutputSettings: { try self.buildVideoOutputSettings() },
            validate: { await self.validateVideoOutputSettings(for: $0) },
            makeWorkingOutputURL: { sourceURL in
                VideoConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedOutputFormat)
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await VideoConversionEngine.convert(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil
                ) { [weak self] progress in
                    guard let self else { return }
                    await self.updateConversionProgress(
                        self.normalizedBatchProgress(
                            itemProgress: progress,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            },
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(
                    savedURL,
                    primaryOutputKeyPath: \.convertedURL,
                    outputsKeyPath: \.convertedURLs
                )
            },
            onSourceProcessed: removeProcessedVideoSource(_:),
            onError: applyConversionError(_:)
        )
    }

    // MARK: - Image Convert

    func convertImage() async {
        defer { imageConversionTask = nil }

        await performMediaBatchConversion(
            canConvert: canConvertImage,
            primarySourceURL: imageSourceURL,
            queuedSourceURLs: queuedImageSourceURLs,
            missingSourceLog: "No image file to convert.",
            fileExtension: selectedImageOutputFormat.fileExtension,
            outputLabel: "Image",
            destinationErrorCode: -1002,
            runningKeyPath: \.isImageConverting,
            progressKeyPath: \.imageConversionProgress,
            errorMessageKeyPath: \.imageConversionErrorMessage,
            currentBatchIndexKeyPath: \.currentImageBatchIndex,
            totalBatchCountKeyPath: \.totalImageBatchCount,
            skippedSummaryPrefix: "Some image files were skipped:",
            startState: { self.prepareImageConversionStartState() },
            buildOutputSettings: { self.buildImageOutputSettings() },
            validate: { await self.validateImageOutputSettings(for: $0) },
            makeWorkingOutputURL: { sourceURL in
                ImageConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedImageOutputFormat)
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await ImageConversionEngine.convert(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings
                ) { [weak self] progress in
                    guard let self else { return }
                    await self.updateImageConversionProgress(
                        self.normalizedBatchProgress(
                            itemProgress: progress,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            },
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(
                    savedURL,
                    primaryOutputKeyPath: \.convertedImageURL,
                    outputsKeyPath: \.convertedImageURLs
                )
            },
            onSourceProcessed: removeProcessedImageSource(_:),
            onError: applyImageConversionError(_:)
        )
    }

    // MARK: - Audio Convert

    func convertAudio() async {
        defer { audioConversionTask = nil }

        await performMediaBatchConversion(
            canConvert: canConvertAudio,
            primarySourceURL: audioSourceURL,
            queuedSourceURLs: queuedAudioSourceURLs,
            missingSourceLog: "No audio file to convert.",
            fileExtension: selectedAudioOutputFormat.fileExtension,
            outputLabel: "Audio",
            destinationErrorCode: -1003,
            runningKeyPath: \.isAudioConverting,
            progressKeyPath: \.audioConversionProgress,
            errorMessageKeyPath: \.audioConversionErrorMessage,
            currentBatchIndexKeyPath: \.currentAudioBatchIndex,
            totalBatchCountKeyPath: \.totalAudioBatchCount,
            skippedSummaryPrefix: "Some audio files were skipped:",
            treatExportCancellationAsCancelled: true,
            startState: { self.prepareAudioConversionStartState() },
            buildOutputSettings: { self.buildAudioOutputSettings() },
            validate: { await self.validateAudioOutputSettings(for: $0) },
            makeWorkingOutputURL: { sourceURL in
                VideoConversionEngine.temporaryOutputURL(for: sourceURL, format: self.selectedAudioOutputFormat)
            },
            runConversion: { sourceURL, workingOutputURL, outputSettings, index, totalCount in
                try await VideoConversionEngine.convertAudio(
                    inputURL: sourceURL,
                    outputURL: workingOutputURL,
                    outputSettings: outputSettings,
                    inputDurationSeconds: nil
                ) { [weak self] progress in
                    guard let self else { return }
                    await self.updateAudioConversionProgress(
                        self.normalizedBatchProgress(
                            itemProgress: progress,
                            index: index,
                            totalCount: totalCount
                        )
                    )
                }
            },
            onSavedOutput: { savedURL in
                self.appendConvertedOutput(
                    savedURL,
                    primaryOutputKeyPath: \.convertedAudioURL,
                    outputsKeyPath: \.convertedAudioURLs
                )
            },
            onSourceProcessed: removeProcessedAudioSource(_:),
            onError: applyAudioConversionError(_:)
        )
    }

    // MARK: - Progress

    func setProgress(_ rawProgress: Double, at keyPath: ReferenceWritableKeyPath<ContentViewModel, Double>) {
        self[keyPath: keyPath] = clampedProgress(rawProgress)
    }

    func normalizedBatchProgress(
        itemProgress: Double,
        index: Int,
        totalCount: Int
    ) -> Double {
        let base = Double(index)
        let total = Double(max(totalCount, 1))
        return (base + itemProgress) / total
    }

    func updateConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.conversionProgress)
    }

    func updateImageConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.imageConversionProgress)
    }

    func updateAudioConversionProgress(_ rawProgress: Double) {
        setProgress(rawProgress, at: \.audioConversionProgress)
    }
}
