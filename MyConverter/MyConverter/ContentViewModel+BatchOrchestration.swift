import Foundation

extension ContentViewModel {
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
}
