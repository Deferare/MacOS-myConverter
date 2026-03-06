import Foundation

extension ContentViewModel {
    func moveSelectedSource(from draggedURL: URL, to targetURL: URL, for kind: MediaKind) {
        let descriptor = mediaStateDescriptor(for: kind)

        moveSelectedSource(
            from: draggedURL,
            to: targetURL,
            isConversionRunning: self[keyPath: descriptor.isConverting],
            currentPrimaryURL: self[keyPath: descriptor.sourceURL],
            selectedSourceURLs: selectedSourceURLs(for: kind),
            assignSelection: { reordered in
                assignSelection(reordered, for: kind)
            },
            cancelAnalysisTask: {
                cancelTask(at: descriptor.analysisTask)
            },
            resetCompatibilityState: {
                resetCompatibilityStateForSelectionChange(for: kind)
            },
            applyStoredSettingsForSourceID: { sourceID in
                applyStoredSettings(for: kind, sourceID: sourceID)
            },
            analyzeSelection: { urls in
                reanalyzeSelection(urls, for: kind)
            }
        )
    }

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

    func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        ContentViewModelSupport.reorderedURLsByMoving(draggedURL, to: targetURL, in: urls)
    }

    func resetCompatibilityStateForSelectionChange(for kind: MediaKind) {
        switch kind {
        case .image:
            resetImageCompatibilityState(resetMetadata: true)
        case .video, .audio:
            resetCompatibilityState(for: kind, resetImageMetadata: false)
        }
    }

    func reanalyzeSelection(_ urls: [URL], for kind: MediaKind) {
        switch kind {
        case .video:
            analyzeSourceCompatibility(for: urls)
        case .image:
            analyzeImageSourceCompatibility(for: urls)
        case .audio:
            analyzeAudioSourceCompatibility(for: urls)
        }
    }
}
