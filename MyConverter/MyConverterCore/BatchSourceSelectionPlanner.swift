import Foundation

struct BatchSourceSelection: Equatable, Sendable {
    let allSourceURLs: [URL]
    let sourceURLs: [URL]
    let shouldResumePartialBatch: Bool
}

enum BatchSourceSelectionPlanner {
    static func resolve(
        primarySourceURL: URL?,
        queuedSourceURLs: [URL],
        completedSourceIDs: Set<String>,
        sourceIdentifier: (URL) -> String = defaultSourceIdentifier(for:)
    ) -> BatchSourceSelection? {
        guard let primarySourceURL else { return nil }

        let allSourceURLs = [primarySourceURL] + queuedSourceURLs
        let remainingSourceURLs = allSourceURLs.filter { sourceURL in
            !completedSourceIDs.contains(sourceIdentifier(sourceURL))
        }
        let shouldResumePartialBatch =
            !completedSourceIDs.isEmpty &&
            !remainingSourceURLs.isEmpty &&
            remainingSourceURLs.count < allSourceURLs.count

        return BatchSourceSelection(
            allSourceURLs: allSourceURLs,
            sourceURLs: shouldResumePartialBatch ? remainingSourceURLs : allSourceURLs,
            shouldResumePartialBatch: shouldResumePartialBatch
        )
    }

    nonisolated private static func defaultSourceIdentifier(for url: URL) -> String {
        url.standardizedFileURL.path
    }
}
