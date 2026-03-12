import XCTest
@testable import MyConverterCore

final class MyConverterCoreTests: XCTestCase {
    func testOutputDestinationHandleStandardizesURL() {
        let rawURL = URL(fileURLWithPath: "/tmp/../tmp/example")
        let handle = OutputDestinationHandle(url: rawURL)

        XCTAssertEqual(handle.kind, .folder)
        XCTAssertEqual(handle.url, rawURL)
        XCTAssertNil(handle.bookmarkData)
    }

    func testUnavailableFFmpegErrorDescriptionPreservesMessage() {
        let error = FFmpegRuntimeError.unavailable("bridge unavailable")
        XCTAssertEqual(error.errorDescription, "bridge unavailable")
    }

    func testInProcessRuntimeProviderDefaultsToUnavailableBridge() {
        XCTAssertNil(InProcessFFmpegRuntime.makeIfAvailable())
    }
}
