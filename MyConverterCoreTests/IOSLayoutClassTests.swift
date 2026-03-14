import XCTest
@testable import MyConverterCore

final class IOSLayoutClassTests: XCTestCase {
    func testCompactLayoutUsesCompactSizeClass() {
        let layout = IOSLayoutClass.resolve(
            hasCompactWidth: true,
            availableWidth: 820
        )

        XCTAssertEqual(layout, .compact)
    }

    func testCompactLayoutUsesNarrowWidthEvenWithoutCompactSizeClass() {
        let layout = IOSLayoutClass.resolve(
            hasCompactWidth: false,
            availableWidth: 390
        )

        XCTAssertEqual(layout, .compact)
    }

    func testRegularLayoutRequiresWideRegularWidth() {
        let layout = IOSLayoutClass.resolve(
            hasCompactWidth: false,
            availableWidth: 900
        )

        XCTAssertEqual(layout, .regular)
    }
}
