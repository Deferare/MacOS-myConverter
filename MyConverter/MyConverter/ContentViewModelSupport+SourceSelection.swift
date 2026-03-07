import Foundation

extension ContentViewModelSupport {
    static func sourceIdentifier(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    static func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var unique: [URL] = []

        for url in urls {
            // Preserve the original URL object to keep any attached security scope.
            let key = sourceIdentifier(for: url)
            if seen.insert(key).inserted {
                unique.append(url)
            }
        }

        return unique
    }

    static func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        let draggedID = sourceIdentifier(for: draggedURL)
        let targetID = sourceIdentifier(for: targetURL)
        guard draggedID != targetID else { return nil }

        var reordered = urls
        var indicesBySourceID: [String: Int] = [:]
        indicesBySourceID.reserveCapacity(reordered.count)

        for (index, url) in reordered.enumerated() {
            indicesBySourceID[sourceIdentifier(for: url)] = index
        }

        guard
            let sourceIndex = indicesBySourceID[draggedID],
            let destinationIndex = indicesBySourceID[targetID],
            sourceIndex != destinationIndex
        else {
            return nil
        }

        let movedURL = reordered.remove(at: sourceIndex)
        reordered.insert(movedURL, at: destinationIndex)
        return reordered
    }
}
