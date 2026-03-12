import Foundation

struct OutputDestinationHandle: Equatable, Sendable {
    enum Kind: String, Sendable {
        case folder
    }

    let kind: Kind
    let url: URL
    let bookmarkData: Data?

    init(
        kind: Kind = .folder,
        url: URL,
        bookmarkData: Data? = nil
    ) {
        self.kind = kind
        self.url = url
        self.bookmarkData = bookmarkData
    }
}

@MainActor
protocol OutputDestinationCoordinator: AnyObject {
    func chooseOutputDestination(
        suggestedDirectory: URL,
        outputLabel: String,
        fileCount: Int
    ) async -> OutputDestinationHandle?
}
