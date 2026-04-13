import XCTest

final class OpenNowUITests: XCTestCase {
    private enum LaunchEnvironmentKey {
        static let defaultsSuite = "OPENNOW_DEFAULTS_SUITE"
        static let testFile = "OPENNOW_TEST_FILE"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesIntoEmptyState() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.buttons["Open Markdown…"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No Outline Yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOpensMarkdownFileFromLaunchEnvironment() throws {
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("OpenNowUITest.md")
        try """
        # UI Test Title

        Body
        """.write(to: temporaryURL, atomically: true, encoding: .utf8)

        let app = makeApp()
        app.launchEnvironment[LaunchEnvironmentKey.testFile] = temporaryURL.path
        app.launch()

        let documentHeader = app.descendants(matching: .any).matching(identifier: "document-header").firstMatch
        XCTAssertTrue(documentHeader.waitForExistence(timeout: 10))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeApp().launch()
        }
    }

    @MainActor
    func testDocumentLayoutKeepsSidebarHeaderAndReaderSeparated() throws {
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent("OpenNowUILayout.md")
        try """
        # Layout Title

        ## Overview

        This paragraph exists to force a visible reading area.

        ## Table

        | Name | Value | Notes |
        | --- | --- | --- |
        | alpha | 1 | row |
        | beta | 2 | row |

        ## Code

        ```swift
        let message = "OpenNow layout smoke test"
        print(message)
        ```
        """.write(to: temporaryURL, atomically: true, encoding: .utf8)

        let app = makeApp()
        app.launchEnvironment[LaunchEnvironmentKey.testFile] = temporaryURL.path
        app.launch()

        let detailPane = app.descendants(matching: .any).matching(identifier: "reader-detail-pane").firstMatch
        let sidebar = app.descendants(matching: .any).matching(identifier: "sidebar-pane").firstMatch
        let window = app.windows.firstMatch

        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(detailPane.waitForExistence(timeout: 10))
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10))

        let windowFrame = window.frame
        let outlineFrame = sidebar.frame
        let detailFrame = detailPane.frame

        XCTAssertGreaterThan(windowFrame.width, 700)
        XCTAssertGreaterThan(outlineFrame.width, windowFrame.width * 0.15)
        XCTAssertGreaterThan(detailFrame.width, windowFrame.width * 0.5)
        XCTAssertGreaterThan(detailFrame.width, outlineFrame.width)
        XCTAssertLessThanOrEqual(detailFrame.maxX, windowFrame.maxX)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Document Layout"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment[LaunchEnvironmentKey.defaultsSuite] = "OpenNowUITests-\(UUID().uuidString)"
        return app
    }
}
