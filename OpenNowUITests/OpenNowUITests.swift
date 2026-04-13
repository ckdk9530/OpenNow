import XCTest

final class OpenNowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesIntoEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Open a Markdown File"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOpensMarkdownFileFromLaunchEnvironment() throws {
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("OpenNowUITest.md")
        try """
        # UI Test Title

        Body
        """.write(to: temporaryURL, atomically: true, encoding: .utf8)

        let app = XCUIApplication()
        app.launchEnvironment["OPENNOW_TEST_FILE"] = temporaryURL.path
        app.launch()

        XCTAssertTrue(app.staticTexts["OpenNowUITest.md"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
