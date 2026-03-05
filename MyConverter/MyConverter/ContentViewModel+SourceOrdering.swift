import Foundation

extension ContentViewModel {
    func moveSelectedSource(
        from draggedURL: URL,
        to targetURL: URL,
        isConversionRunning: Bool,
        currentPrimaryURL: URL?,
        selectedSourceURLs: [URL],
        assignSelection: ([URL]) -> Void,
        cancelAnalysisTask: () -> Void,
        resetCompatibilityState: () -> Void,
        applyStoredSettingsForSourceID: (String) -> Void,
        analyzeSelection: ([URL]) -> Void
    ) {
        guard !isConversionRunning else { return }
        let previousPrimaryID = currentPrimaryURL.map(sourceIdentifier(for:))
        guard let reordered = reorderedURLsByMoving(draggedURL, to: targetURL, in: selectedSourceURLs) else {
            return
        }

        assignSelection(reordered)

        guard let newPrimarySourceURL = reordered.first else { return }
        guard sourceIdentifier(for: newPrimarySourceURL) != previousPrimaryID else { return }

        cancelAnalysisTask()
        resetCompatibilityState()

        let sourceID = sourceIdentifier(for: newPrimarySourceURL)
        applyStoredSettingsForSourceID(sourceID)
        analyzeSelection(reordered)
    }

    func moveSelectedVideoSource(from draggedURL: URL, to targetURL: URL) {
        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: isConverting,
            currentPrimaryURL: sourceURL,
            selectedSourceURLs: selectedVideoSourceURLs,
            assignSelection: { reordered in
                assignVideoSelection(reordered)
            },
            cancelAnalysisTask: {
                cancelTask(&sourceAnalysisTask)
            },
            resetCompatibilityState: {
                resetVideoCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredVideoSettings(for: sourceID)
            },
            analyzeSelection: { urls in
                analyzeSourceCompatibility(for: urls)
            }
        )
    }

    func moveSelectedImageSource(from draggedURL: URL, to targetURL: URL) {
        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: isImageConverting,
            currentPrimaryURL: imageSourceURL,
            selectedSourceURLs: selectedImageSourceURLs,
            assignSelection: { reordered in
                assignImageSelection(reordered)
            },
            cancelAnalysisTask: {
                cancelTask(&imageSourceAnalysisTask)
            },
            resetCompatibilityState: {
                resetImageCompatibilityState(resetMetadata: true)
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredImageSettings(for: sourceID)
            },
            analyzeSelection: { urls in
                analyzeImageSourceCompatibility(for: urls)
            }
        )
    }

    func moveSelectedAudioSource(from draggedURL: URL, to targetURL: URL) {
        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: isAudioConverting,
            currentPrimaryURL: audioSourceURL,
            selectedSourceURLs: selectedAudioSourceURLs,
            assignSelection: { reordered in
                assignAudioSelection(reordered)
            },
            cancelAnalysisTask: {
                cancelTask(&audioSourceAnalysisTask)
            },
            resetCompatibilityState: {
                resetAudioCompatibilityMessages()
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredAudioSettings(for: sourceID)
            },
            analyzeSelection: { urls in
                analyzeAudioSourceCompatibility(for: urls)
            }
        )
    }

    func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        ContentViewModelSupport.reorderedURLsByMoving(draggedURL, to: targetURL, in: urls)
    }
}
