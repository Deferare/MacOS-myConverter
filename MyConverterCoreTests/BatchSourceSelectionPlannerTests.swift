import XCTest
@testable import MyConverterCore

final class BatchSourceSelectionPlannerTests: XCTestCase {
    func testResolveReturnsNilWithoutPrimarySource() {
        let selection = BatchSourceSelectionPlanner.resolve(
            primarySourceURL: nil,
            queuedSourceURLs: [makeURL("queued.mp4")],
            completedSourceIDs: []
        )

        XCTAssertNil(selection)
    }

    func testResolveKeepsAllSourcesWhenNothingWasCompleted() {
        let first = makeURL("first.mp4")
        let second = makeURL("second.mp4")

        let selection = BatchSourceSelectionPlanner.resolve(
            primarySourceURL: first,
            queuedSourceURLs: [second],
            completedSourceIDs: []
        )

        XCTAssertEqual(
            selection,
            BatchSourceSelection(
                allSourceURLs: [first, second],
                sourceURLs: [first, second],
                shouldResumePartialBatch: false
            )
        )
    }

    func testResolveResumesOnlyRemainingSourcesWhenBatchIsPartiallyCompleted() {
        let first = makeURL("first.mp4")
        let second = makeURL("second.mp4")
        let third = makeURL("third.mp4")

        let selection = BatchSourceSelectionPlanner.resolve(
            primarySourceURL: first,
            queuedSourceURLs: [second, third],
            completedSourceIDs: [first.standardizedFileURL.path]
        )

        XCTAssertEqual(
            selection,
            BatchSourceSelection(
                allSourceURLs: [first, second, third],
                sourceURLs: [second, third],
                shouldResumePartialBatch: true
            )
        )
    }

    func testResolveRestartsEntireBatchWhenEverythingWasAlreadyCompleted() {
        let first = makeURL("first.mp4")
        let second = makeURL("second.mp4")

        let selection = BatchSourceSelectionPlanner.resolve(
            primarySourceURL: first,
            queuedSourceURLs: [second],
            completedSourceIDs: [
                first.standardizedFileURL.path,
                second.standardizedFileURL.path
            ]
        )

        XCTAssertEqual(
            selection,
            BatchSourceSelection(
                allSourceURLs: [first, second],
                sourceURLs: [first, second],
                shouldResumePartialBatch: false
            )
        )
    }

    func testResolveUsesInjectedSourceIdentifierForCompletedMatching() {
        let first = URL(fileURLWithPath: "/tmp/exports/../exports/first.mp4")
        let second = URL(fileURLWithPath: "/tmp/exports/second.mp4")

        let selection = BatchSourceSelectionPlanner.resolve(
            primarySourceURL: first,
            queuedSourceURLs: [second],
            completedSourceIDs: ["/tmp/exports/first.mp4"],
            sourceIdentifier: { $0.standardizedFileURL.path }
        )

        XCTAssertEqual(selection?.sourceURLs, [second])
        XCTAssertEqual(selection?.shouldResumePartialBatch, true)
    }

    private func makeURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }
}
