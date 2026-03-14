import Foundation

extension ContentViewModel.MediaKind {
    func prepareConversionStartState(
        in viewModel: ContentViewModel,
        preserveCompletedOutputs: Bool = false
    ) {
        setConverting(true, in: viewModel)
        if !preserveCompletedOutputs {
            setConvertedURL(nil, in: viewModel)
            setConvertedURLs([], in: viewModel)
            setConvertedOutputURLsBySourceID([:], in: viewModel)
        }
        setProcessedSourceIDs([], in: viewModel)
        setConversionErrorMessage(nil, in: viewModel)
        setProgress(0, in: viewModel)
    }

    func appendConvertedOutput(
        _ outputURL: URL,
        from sourceURL: URL,
        in viewModel: ContentViewModel
    ) {
        let sourceID = viewModel.sourceIdentifier(for: sourceURL)
        setConvertedURL(outputURL, in: viewModel)

        var convertedURLs = convertedURLs(in: viewModel)
        convertedURLs.append(outputURL)
        setConvertedURLs(convertedURLs, in: viewModel)

        var convertedOutputURLsBySourceID = convertedOutputURLsBySourceID(in: viewModel)
        convertedOutputURLsBySourceID[sourceID] = outputURL
        setConvertedOutputURLsBySourceID(convertedOutputURLsBySourceID, in: viewModel)
    }

    func markProcessedSource(_ sourceURL: URL, in viewModel: ContentViewModel) {
        var processedSourceIDs = processedSourceIDs(in: viewModel)
        processedSourceIDs.insert(viewModel.sourceIdentifier(for: sourceURL))
        setProcessedSourceIDs(processedSourceIDs, in: viewModel)
    }

    func mediaStateSnapshot(in viewModel: ContentViewModel) -> ContentViewModel.MediaStateSnapshot {
        ContentViewModel.MediaStateSnapshot(
            sourceURL: sourceURL(in: viewModel),
            queuedSourceURLs: queuedSourceURLs(in: viewModel),
            convertedURLs: convertedURLs(in: viewModel),
            convertedOutputURLsBySourceID: convertedOutputURLsBySourceID(in: viewModel),
            processedSourceIDs: processedSourceIDs(in: viewModel),
            conversionErrorMessage: conversionErrorMessage(in: viewModel),
            compatibilityWarningMessage: compatibilityWarningMessage(in: viewModel),
            isAnalyzing: isAnalyzing(in: viewModel),
            isConverting: isConverting(in: viewModel),
            progress: viewModel[keyPath: mediaStateDescriptor.progress],
            currentBatchIndex: currentBatchIndex(in: viewModel),
            totalBatchCount: totalBatchCount(in: viewModel)
        )
    }
}
