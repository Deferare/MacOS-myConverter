import Foundation

extension ContentViewModel {
    nonisolated static func buildPreparedSingleVideoSelection(
        for sourceURL: URL
    ) async -> PreparedSingleVideoSelection? {
        let token = PerformanceSignpost.begin("SingleVideoPrepare", message: sourceURL.lastPathComponent)
        let assetTrackProbe = await VideoConversionEngine.assetTrackProbe(for: sourceURL)

        var stagedInputLease: FFmpegStagingSupport.StagedInputLease?
        if !assetTrackProbe.isReadable, FFmpegBinaryLocator.findPath() != nil {
            stagedInputLease = try? FFmpegStagingSupport.acquireLease(
                for: sourceURL,
                makeError: { code, message in
                    ConversionError.ffmpegFailed(code, message)
                }
            )
        }

        let sourceCapabilities = await VideoConversionEngine.sourceCapabilities(
            for: sourceURL,
            stagedInputLease: stagedInputLease
        )

        guard !Task.isCancelled else {
            if let stagedInputLease {
                FFmpegStagingSupport.releaseLease(stagedInputLease)
            }
            PerformanceSignpost.end("SingleVideoPrepare", token: token, message: "cancelled")
            return nil
        }

        PerformanceSignpost.end("SingleVideoPrepare", token: token, message: sourceURL.lastPathComponent)
        return PreparedSingleVideoSelection(
            sourceID: ContentViewModelSupport.sourceIdentifier(for: sourceURL),
            sourceURL: sourceURL,
            preparedSourceContext: VideoConversionEngine.PreparedSourceContext(
                sourceCapabilities: sourceCapabilities,
                assetTrackProbe: assetTrackProbe,
                candidatePresets: nil,
                stagedInputLease: stagedInputLease
            )
        )
    }

    func preparedSingleVideoSelection(for sourceURL: URL) -> PreparedSingleVideoSelection? {
        let sourceID = sourceIdentifier(for: sourceURL)
        guard let prepared = selectionPreparationState.preparedSingleVideoSelection,
              prepared.sourceID == sourceID else {
            return nil
        }

        return prepared
    }

    func storePreparedSingleVideoSelection(_ prepared: PreparedSingleVideoSelection) {
        clearPreparedSingleVideoSelection(
            excludingSourceID: prepared.sourceID,
            excludingStagedInputLease: prepared.preparedSourceContext.stagedInputLease
        )
        selectionPreparationState.preparedSingleVideoSelection = prepared
    }

    func clearPreparedSingleVideoSelection(for kind: MediaKind) {
        guard kind == .video else { return }
        clearPreparedSingleVideoSelection()
    }

    func clearPreparedSingleVideoSelection() {
        clearPreparedSingleVideoSelection(
            excludingSourceID: nil,
            excludingStagedInputLease: nil
        )
    }

    func clearPreparedSingleVideoSelection(
        excludingSourceID: String?,
        excludingStagedInputLease: FFmpegStagingSupport.StagedInputLease?
    ) {
        guard let prepared = selectionPreparationState.preparedSingleVideoSelection else { return }
        guard prepared.sourceID != excludingSourceID ||
                prepared.preparedSourceContext.stagedInputLease?.cacheKey != excludingStagedInputLease?.cacheKey else {
            return
        }

        if let stagedInputLease = prepared.preparedSourceContext.stagedInputLease,
           stagedInputLease.cacheKey != excludingStagedInputLease?.cacheKey {
            FFmpegStagingSupport.releaseLease(stagedInputLease)
        }
        selectionPreparationState.preparedSingleVideoSelection = nil
    }

    func canRetainPreparedSingleVideoSelection(_ prepared: PreparedSingleVideoSelection) -> Bool {
        let selectedSourceIDs = selectedSourceIDs(for: .video)
        return selectedSourceIDs.count == 1 && selectedSourceIDs.first == prepared.sourceID
    }

    func prepareSelectedSingleVideoSelectionIfNeeded(
        for sourceURL: URL
    ) async -> PreparedSingleVideoSelection? {
        if let prepared = preparedSingleVideoSelection(for: sourceURL) {
            PerformanceSignpost.event("SingleVideoPrepareReuse", message: sourceURL.lastPathComponent)
            return prepared
        }

        let prepared = await detachedTaskValue(priority: .userInitiated) {
            await Self.buildPreparedSingleVideoSelection(for: sourceURL)
        }

        guard let prepared else { return nil }
        guard canRetainPreparedSingleVideoSelection(prepared) else {
            if let stagedInputLease = prepared.preparedSourceContext.stagedInputLease {
                FFmpegStagingSupport.releaseLease(stagedInputLease)
            }
            return nil
        }

        storePreparedSingleVideoSelection(prepared)
        return prepared
    }
}
